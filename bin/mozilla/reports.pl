
require "$form->{path}/lib.pl";
require "$form->{path}/mylib.pl";

1;

#===============================
sub continue { &{$form->{nextsub}} };

#=================================================
#
# Inventory Onhand Qty and Value by Based on FIFO
#
#=================================================
#-------------------------------
sub onhandvalue_search {
   $form->{title} = $locale->text('Inventory Onhand Value');
   &print_title;

   &start_form;
   &start_table;

   &bld_department;
   &bld_warehouse;
   &bld_partsgroup;

   #&print_date('dateto', $locale->text('To'));
   &print_text('partnumber', $locale->text('Number'), 20);
   &print_select('partsgroup', $locale->text('Group'));
   #&print_select('department', $locale->text('Department'));
   #&print_select('warehouse', $locale->text('Warehouse'));
 
   print qq|<tr><th align=right>| . $locale->text('Include in Report') . qq|</th><td>|;

   #&print_radio;
   &print_checkbox('l_no', $locale->text('No.'), '', '');
   #&print_checkbox('l_warehouse', $locale->text('Warehouse'), 'checked', '');
   &print_checkbox('l_partnumber', $locale->text('Number'), 'checked', '');
   &print_checkbox('l_description', $locale->text('Description'), 'checked', '');
   &print_checkbox('l_partsgroup', $locale->text('Group'), 'checked', '');
   &print_checkbox('l_unit', $locale->text('Unit'), 'checked', '<br>');
   &print_checkbox('l_onhand_qty', $locale->text('Onhand Qty'), 'checked', '');
   &print_checkbox('l_components', $locale->text('Components'), '', '');
   &print_checkbox('l_onhand_amt', $locale->text('Onhand Amount'), 'checked', '<br>');
   &print_checkbox('l_subtotal', $locale->text('Subtotal'), '', '');
   &print_checkbox('l_csv', $locale->text('CSV'), '', '');
   &print_checkbox('l_sql', $locale->text('SQL'), '');
   print qq|</td></tr>|;
   &end_table;
   print('<hr size=3 noshade>');
   $form->{nextsub} = 'onhandvalue_list';
   &print_hidden('nextsub');
   &add_button($locale->text('Continue'));
   &end_form;
}

#-------------------------------
sub onhandvalue_list {
  # callback to report list
   my $callback = qq|$form->{script}?action=onhandvalue_list|;
   for (qw(path login sessionid)) { $callback .= "&$_=$form->{$_}" }

   &split_combos('department,warehouse,partsgroup');
   $form->{department_id} *= 1;
   $form->{warehouse_id} *= 1;
   $form->{partsgroup_id} *= 1;
   $partnumber = $form->like(lc $form->{partnumber});
   $description = $form->like(lc $form->{description});
   
   my $where = qq| (1 = 1)|;
   my $subwhere = '';
   $where .= qq| AND (LOWER(p.partnumber) LIKE '$partnumber')| if $form->{partnumber};
   $where .= qq| AND (LOWER(p.description) LIKE '$name')| if $form->{description};
   $where .= qq| AND (p.partsgroup_id = $form->{partsgroup_id})| if $form->{partsgroup};
   #$where .= qq| AND (i.department_id = $form->{department_id})| if $form->{department};
   #$where .= qq| AND (i.warehouse_id = $form->{warehouse_id})| if $form->{warehouse};
   $subwhere .= qq| AND (i.transdate <= '$form->{dateto}')| if $form->{dateto};

   my $componentswhere;
   $componentswhere = qq| AND i.assemblyitem IS FALSE| if !$form->{l_components};

   @columns = qw(id warehouse partnumber description partsgroup unit onhand_qty onhand_amt);
   # if this is first time we are running this report.
   $form->{sort} = 'partnumber' if !$form->{sort};
   $form->{oldsort} = 'none' if !$form->{oldsort};
   $form->{direction} = 'ASC' if !$form->{direction};
   @columns = $form->sort_columns(@columns);

   my %ordinal = (	id => 1,
			warehouse => 2,
			partnumber => 3,
			description => 4,
			partsgroup => 5,
			unit => 6,
			onhand_qty => 7,
			onhand_amt => 8
   );
   my $sort_order = $form->sort_order(\@columns, \%ordinal);

   # No. columns should always come first
   splice @columns, 0, 0, 'no';

   # Select columns selected for report display
   foreach $item (@columns) {
     if ($form->{"l_$item"} eq "Y") {
       push @column_index, $item;

       # add column to href and callback
       $callback .= "&l_$item=Y";
     }
   }
   for (qw(l_subtotal l_components department warehouse partsgroup partnumber description dateto)){
      $callback .= "&$_=".$form->escape($form->{$_});
   }
   my $href = $callback;
   $form->{callback} = $form->escape($callback,1);

   $query = qq|SELECT 
		p.id,
		p.partnumber,
		p.description,
		pg.partsgroup,
		p.unit,
		SUM(0-(i.qty+i.allocated)) AS onhand_qty,
		SUM((0-(i.qty+i.allocated))*i.lastcost) AS onhand_amt

		FROM parts p
		JOIN invoice i ON (i.parts_id = p.id)
		LEFT JOIN partsgroup pg ON (pg.id = p.partsgroup_id)

		WHERE $where
		AND (i.qty+i.allocated) <> 0
		AND p.inventory_accno_id IS NOT NULL
		$componentswhere

		GROUP BY 1,2,3,4,5
		HAVING SUM(0-(i.qty+i.allocated)) <> 0

		ORDER BY $form->{sort} $form->{direction}
	|;

   # store oldsort/direction information
   $href .= "&direction=$form->{direction}&oldsort=$form->{sort}";

   $column_header{no}   	= rpt_hdr('no', $locale->text('No.'));
   $column_header{partnumber} 	= rpt_hdr('partnumber', $locale->text('Number'), $href);
   $column_header{description} 	= rpt_hdr('description', $locale->text('Description'), $href);
   $column_header{partsgroup}  	= rpt_hdr('partsgroup', $locale->text('Group'), $href);
   $column_header{unit}  	= rpt_hdr('unit', $locale->text('Unit'), $href);
   $column_header{onhand_qty}  	= rpt_hdr('onhand_qty', $locale->text('Onhand Qty'));
   $column_header{onhand_amt}  	= rpt_hdr('onhand_amt', $locale->text('Onhand Amount'));

   $dbh = $form->dbconnect(\%myconfig);
   my %defaults = $form->get_defaults($dbh, \@{['precision', 'company']});
   for (keys %defaults) { $form->{$_} = $defaults{$_} }

   if ($form->{l_csv} eq 'Y'){
	&export_to_csv($dbh, $query, 'parts_onhand');
	exit;
   }
   $sth = $dbh->prepare($query);
   $sth->execute || $form->dberror($query);

   $form->{title} = $locale->text('Inventory Onhand Value');
   &print_title;
   &print_criteria('partnumber', $locale->text('Number'));
   &print_criteria('warehouse_name', $locale->text('Warehouse'));
   &print_criteria('department_name', $locale->text('Department'));
   &print_criteria('dateto', $locale->text('To'));

   $form->info($query) if $form->{l_sql};
   print qq|<table width=100%><tr class=listheading>|;
   # print header
   for (@column_index) { print "\n$column_header{$_}" }
   print qq|</tr>|; 

   # Subtotal and total variables
   my $onhand_qty_total, $onhand_amt_total;

   # print data
   my $i = 1; my $no = 1;
   while (my $ref = $sth->fetchrow_hashref(NAME_lc)){
   	$form->{link} = qq|$form->{script}?action=onhandvalue_detail&id=$ref->{id}&l_components=$form->{l_components}&l_sql=$form->{l_sql}&path=$form->{path}&login=$form->{login}&callback=$form->{callback}|;

	$column_data{no}   		= rpt_txt($no);
   	$column_data{partnumber}	= rpt_txt($ref->{partnumber});
   	$column_data{description} 	= rpt_txt($ref->{description}, $form->{link});
   	$column_data{partsgroup}    	= rpt_txt($ref->{partsgroup});
   	$column_data{unit}    		= rpt_txt($ref->{unit});
   	$column_data{onhand_qty}    	= rpt_dec($ref->{onhand_qty});
   	$column_data{onhand_amt}    	= rpt_dec($ref->{onhand_amt});

	print "<tr valign=top class=listrow$i>";
	for (@column_index) { print "\n$column_data{$_}" }
	print "</tr>";
	$i++; $i %= 2; $no++;

	$onhand_qty_total += $ref->{onhand_qty};
	$onhand_amt_total += $ref->{onhand_amt};
   }

   # prepare data for footer
   for (@column_index) { $column_data{$_} = rpt_txt('&nbsp;') }
   $column_data{onhand_qty}    	= rpt_dec($onhand_qty_total);
   $column_data{onhand_amt}    	= rpt_dec($onhand_amt_total);

   # print footer
   print "<tr valign=top class=listtotal>";
   for (@column_index) { print "\n$column_data{$_}" }
   print "</tr>";

   print qq|</table>|;
   $sth->finish;
   $dbh->disconnect;
}

#-------------------------------
sub onhandvalue_detail {
  # callback to report list
   my $callback = qq|$form->{script}?action=onhandvalue_list|;
   for (qw(path login sessionid)) { $callback .= "&$_=$form->{$_}" }

   my $where = qq| (1 = 1)|;
   $where .= qq| AND parts_id = $form->{id}|;

   my $componentswhere;
   $componentswhere = qq| AND i.assemblyitem IS FALSE| if !$form->{l_components};

   @columns = qw(transdate invnumber qty sellprice extended);
   # if this is first time we are running this report.
   $form->{sort} = 'transdate' if !$form->{sort};
   $form->{oldsort} = 'none' if !$form->{oldsort};
   $form->{direction} = 'ASC' if !$form->{direction};
   @columns = $form->sort_columns(@columns);

   my %ordinal = (	invnumber => 1,
			transdate => 2,
			qty => 3,
			sellprice => 4,
			extended => 5
   );
   my $sort_order = $form->sort_order(\@columns, \%ordinal);

   # No. columns should always come first
   splice @columns, 0, 0, 'no';
   for (qw(no invnumber transdate qty sellprice extended)) { $form->{"l_$_"} = 'Y' }

   # Select columns selected for report display
   foreach $item (@columns) {
     if ($form->{"l_$item"} eq "Y") {
       push @column_index, $item;

       # add column to href and callback
       $callback .= "&l_$item=Y";
     }
   }
   $callback .= "&l_subtotal=$form->{l_subtotal}";
   my $href = $callback;
   $form->{callback} = $form->escape($callback,1);

   $dbh = $form->dbconnect(\%myconfig);
   $query = qq|SELECT partnumber, description FROM parts WHERE id=$form->{id}|;
   ($form->{partnumber}, $form->{description}) = $dbh->selectrow_array($query);

   $query = qq|SELECT
		ap.id,
		ap.invnumber,
		ap.transdate,
		(i.qty + i.allocated) * -1 AS qty,
		'ir' AS module,
		i.sellprice

		FROM ap
		JOIN invoice i ON (i.trans_id = ap.id)
		WHERE $where 
		AND i.qty + i.allocated <> 0
		$componentswhere

	      UNION ALL

	      SELECT 
		ar.id,
		ar.invnumber,
		ar.transdate,
		(i.qty + i.allocated) * -1 AS qty,
		'is' AS module,
		i.sellprice

		FROM ar
		JOIN invoice i ON (i.trans_id = ar.id)
		WHERE $where 
		AND i.qty + i.allocated <> 0
		$componentswhere

	      ORDER BY $form->{sort} $form->{direction}
	|;

   # store oldsort/direction information
   $href .= "&direction=$form->{direction}&oldsort=$form->{sort}";

   $column_header{no}   	= rpt_hdr('no', $locale->text('No.'));
   $column_header{invnumber} 	= rpt_hdr('invnumber', $locale->text('Invoice'), $href);
   $column_header{transdate} 	= rpt_hdr('transdate', $locale->text('Date'), $href);
   $column_header{qty}  	= rpt_hdr('qty', $locale->text('Qty'), $href);
   $column_header{sellprice}  	= rpt_hdr('sellprice', $locale->text('Price'), $href);
   $column_header{extended}  	= rpt_hdr('extended', $locale->text('Extended'));

   my %defaults = $form->get_defaults($dbh, \@{['precision', 'company']});
   for (keys %defaults) { $form->{$_} = $defaults{$_} }

   $sth = $dbh->prepare($query);
   $sth->execute || $form->dberror($query);

   $form->{title} = $locale->text('Inventory Onhand Value Detail');
   &print_title;
   print $locale->text('Number') . qq|: $form->{partnumber} / $form->{description}|;

   $form->info($query) if $form->{l_sql};
   print qq|<table width=100%><tr class=listheading>|;
   # print header
   for (@column_index) { print "\n$column_header{$_}" }
   print qq|</tr>|; 

   # Subtotal and total variables
   my $qty_total = 0;
   my $extended_total = 0;

   # print data
   my $i = 1; my $no = 1;
   while (my $ref = $sth->fetchrow_hashref(NAME_lc)){
   	$form->{link} = qq|$ref->{module}.pl?readonly=1&action=edit&id=$ref->{id}&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}&callback=$form->{callback}|;

	$column_data{no}   	= rpt_txt($no);
   	$column_data{invnumber}	= rpt_txt($ref->{invnumber}, $form->{link});
   	$column_data{transdate} = rpt_txt($ref->{transdate});
   	$column_data{qty}    	= rpt_dec($ref->{qty});
   	$column_data{sellprice} = rpt_dec($ref->{sellprice});
   	$column_data{extended} 	= rpt_dec($ref->{qty} * $ref->{sellprice});

	print "<tr valign=top class=listrow$i>";
	for (@column_index) { print "\n$column_data{$_}" }
	print "</tr>";
	$i++; $i %= 2; $no++;

	$qty_total += $ref->{qty};
	$extended_total += $ref->{qty} * $ref->{sellprice};
   }

   # prepare data for footer
   for (@column_index) { $column_data{$_} = rpt_txt('&nbsp;') }
   $column_data{qty}   	  = rpt_dec($qty_total);
   $column_data{extended} = rpt_dec($extended_total);

   # print footer
   print "<tr valign=top class=listtotal>";
   for (@column_index) { print "\n$column_data{$_}" }
   print "</tr>";

   print qq|</table>|;
   $sth->finish;
   $dbh->disconnect;
}

#=================================================
#
# Complete General Ledger
#
#=================================================
#-------------------------------
sub gl_search {
   $form->{title} = $locale->text('General Ledger');
   &print_title;

   &start_form;
   &start_table;

   &bld_department;
   &bld_warehouse;
   &bld_partsgroup;

   &print_date('fromdate', $locale->text('From'));
   &print_date('todate', $locale->text('To'));
   &print_text('fromaccount', $locale->text('Account') . ' >=', 15);
   &print_text('toaccount', $locale->text('Account') . ' <=', 15);
 
   print qq|<tr><th align=right>| . $locale->text('Include in Report') . qq|</th><td>|;

   #&print_radio;
   &print_checkbox('l_no', $locale->text('No.'), '', '');
   &print_checkbox('l_transdate', $locale->text('Date'), 'checked', '');
   &print_checkbox('l_reference', $locale->text('Reference'), 'checked', '');
   &print_checkbox('l_description', $locale->text('Description'), 'checked', '');
   &print_checkbox('l_name', $locale->text('Company Name'), 'checked', '');
   &print_checkbox('l_source', $locale->text('Source'), 'checked', '<br>');
   &print_checkbox('l_debit', $locale->text('Debit'), 'checked', '');
   &print_checkbox('l_credit', $locale->text('Credit'), 'checked', '');
   &print_checkbox('l_balance', $locale->text('Balance'), 'checked', '<br>');
   &print_checkbox('l_group', $locale->text('Group'), '', '');
   #&print_checkbox('l_sql', $locale->text('SQL'), '');
   print qq|</td></tr>|;
   &end_table;
   print('<hr size=3 noshade>');
   $form->{nextsub} = 'gl_list';
   &print_hidden('nextsub');
   &add_button($locale->text('Continue'));
   &end_form;
}

#-------------------------------
sub gl_list {
  # callback to report list
   my $callback = qq|$form->{script}?action=gl_list|;
   for (qw(path login)) { $callback .= "&$_=$form->{$_}" }

   my $glwhere = qq| (1 = 1)|;
   $glwhere .= qq| AND c.accno >= '$form->{fromaccount}'| if $form->{fromaccount};
   $glwhere .= qq| AND c.accno <= '$form->{toaccount}'| if $form->{toaccount};
   $glwhere .= qq| AND ac.transdate >= '$form->{fromdate}'| if $form->{fromdate};
   $glwhere .= qq| AND ac.transdate <= '$form->{todate}'| if $form->{todate};
   $glwhere .= qq| AND ac.amount <> 0|;
   my $arwhere = $glwhere;
   my $apwhere = $glwhere;

   for (qw(fromaccount toaccount fromdate todate)){ $callback .= "&$_=".$form->escape($form->{$_},1) }

   @columns = qw(id transdate reference description name source debit credit balance);
   # if this is first time we are running this report.
   $form->{sort} = '1' if !$form->{sort};
   $form->{oldsort} = 'none' if !$form->{oldsort};
   $form->{direction} = 'ASC' if !$form->{direction};
   @columns = $form->sort_columns(@columns);

   my %ordinal = (	id => 1,
			accno => 2,
			transdate => 3,
			reference => 4,
			description => 5,
			name => 6,
			source => 7,
			debit => 8,
			credit => 9,
			balance => 10
   );
   my $sort_order = $form->sort_order(\@columns, \%ordinal);

   # No. columns should always come first
   splice @columns, 0, 0, 'no';

   # Select columns selected for report display
   foreach $item (@columns) {
     if ($form->{"l_$item"} eq "Y") {
       push @column_index, $item;

       # add column to href and callback
       $callback .= "&l_$item=Y";
     }
   }
   $callback .= "&l_subtotal=$form->{l_subtotal}";
   my $href = $callback;
   $form->{callback} = $form->escape($callback,1);

   my $query;
   if ($form->{l_group}){
     $query = qq|SELECT c.accno, c.description AS accdescription, '' AS name,
		 ac.transdate, g.reference, g.id AS id, 'gl' AS module,
		 0 AS invoice,
		 SUM(ac.amount) AS amount
                 FROM gl g
		 JOIN acc_trans ac ON (g.id = ac.trans_id)
		 JOIN chart c ON (ac.chart_id = c.id)
		 LEFT JOIN department d ON (d.id = g.department_id)
                 WHERE $glwhere
		 GROUP BY 1,2,3,4,5,6,7

		 UNION ALL

	         SELECT c.accno, c.description AS accdescription, ct.name,
		 ac.transdate, a.invnumber, a.id AS id, 'ar' AS module,
		 SUM(CAST(a.invoice AS INTEGER)) AS invoice,
		 SUM(ac.amount) AS amount
		 FROM ar a
		 JOIN acc_trans ac ON (a.id = ac.trans_id)
		 JOIN chart c ON (ac.chart_id = c.id)
		 JOIN customer ct ON (a.customer_id = ct.id)
		 LEFT JOIN department d ON (d.id = a.department_id)
		 WHERE $arwhere
		 GROUP BY 1,2,3,4,5,6

		 UNION ALL

	         SELECT c.accno, c.description AS accdescription, ct.name,
		 ac.transdate, a.invnumber, a.id AS id, 'ap' AS module, 
		 SUM(CAST(a.invoice AS INTEGER)) AS invoice, 
		 SUM(ac.amount) as amount
		 FROM ap a
		 JOIN acc_trans ac ON (a.id = ac.trans_id)
		 JOIN chart c ON (ac.chart_id = c.id)
		 JOIN vendor ct ON (a.vendor_id = ct.id)
		 LEFT JOIN department d ON (d.id = a.department_id)
		 WHERE $apwhere
		 GROUP BY 1,2,3,4,5,6

         	 ORDER BY 1,2,3,4,5,6|;
   } else {
     $query = qq|SELECT g.id, 'gl' AS type, g.reference,
                 g.description, ac.transdate, ac.source,
		 ac.amount, c.accno, g.notes, '' AS name,
		 ac.cleared, d.description AS department,
		 ac.memo, '0' AS name_id, '' AS db,
		 c.description AS accdescription,
		 'gl' AS module, FALSE AS invoice
                 FROM gl g
		 JOIN acc_trans ac ON (g.id = ac.trans_id)
		 JOIN chart c ON (ac.chart_id = c.id)
		 LEFT JOIN department d ON (d.id = g.department_id)
                 WHERE $glwhere

		 UNION ALL

	         SELECT a.id, 'ar' AS type, a.invnumber,
		 a.description, ac.transdate, ac.source,
		 ac.amount, c.accno, a.notes, ct.name,
		 ac.cleared, d.description AS department,
		 ac.memo, ct.id AS name_id, 'customer' AS db,
		 c.description AS accdescription,
		 'ar' AS module, invoice
		 FROM ar a
		 JOIN acc_trans ac ON (a.id = ac.trans_id)
		 JOIN chart c ON (ac.chart_id = c.id)
		 JOIN customer ct ON (a.customer_id = ct.id)
		 JOIN address ad ON (ad.trans_id = ct.id)
		 LEFT JOIN department d ON (d.id = a.department_id)
		 WHERE $arwhere

		 UNION ALL

	         SELECT a.id, 'ap' AS type, a.invnumber,
		 a.description, ac.transdate, ac.source,
		 ac.amount, c.accno, a.notes, ct.name,
		 ac.cleared, d.description AS department,
		 ac.memo, ct.id AS name_id, 'vendor' AS db,
		 c.description AS accdescription,
		 'ap' AS module, invoice
		 FROM ap a
		 JOIN acc_trans ac ON (a.id = ac.trans_id)
		 JOIN chart c ON (ac.chart_id = c.id)
		 JOIN vendor ct ON (a.vendor_id = ct.id)
		 JOIN address ad ON (ad.trans_id = ct.id)
		 LEFT JOIN department d ON (d.id = a.department_id)
		 WHERE $apwhere

         	 ORDER BY 8, 5, 3|;
   }

   # store oldsort/direction information
   $href .= "&direction=$form->{direction}&oldsort=$form->{sort}";

   $column_header{no}   	= rpt_hdr('no', $locale->text('No.'));
   $column_header{transdate} 	= rpt_hdr('transdate', $locale->text('Date'), $href);
   $column_header{reference} 	= rpt_hdr('reference', $locale->text('Reference'), $href);
   $column_header{description} 	= rpt_hdr('description', $locale->text('Description'), $href);
   $column_header{name} 	= rpt_hdr('name', $locale->text('Company Name'), $href);
   $column_header{source}  	= rpt_hdr('source', $locale->text('Source'), $href);
   $column_header{debit}  	= rpt_hdr('debit', $locale->text('Debit'));
   $column_header{credit}  	= rpt_hdr('credit', $locale->text('Credit'));
   $column_header{balance}  	= rpt_hdr('balance', $locale->text('Balance'));

   $form->error($query) if $form->{l_sql};
   $dbh = $form->dbconnect(\%myconfig);
   my %defaults = $form->get_defaults($dbh, \@{['precision', 'company']});
   for (keys %defaults) { $form->{$_} = $defaults{$_} }

   if ($form->{l_csv} eq 'Y'){
	&export_to_csv($dbh, $query, 'parts_onhand');
	exit;
   }
   $sth = $dbh->prepare($query);
   $sth->execute || $form->dberror($query);

   $form->{title} = $locale->text('General Ledger');
   &print_title;
   &print_criteria('fromdate', $locale->text('From'));
   &print_criteria('todate', $locale->text('To'));
   &print_criteria('fromaccount', $locale->text('Account').' >=');
   &print_criteria('toaccount', $locale->text('Account').' <=');


   # Subtotal and total variables
   my $debit_total, $credit_total, $debit_subtotal, $credit_subtotal, $balance;

   # print data
   my $i = 1; my $no = 1;
   my $groupbreak = 'none';
   print qq|<table width=100%>|;
   while (my $ref = $sth->fetchrow_hashref(NAME_lc)){
	if ($groupbreak ne "$ref->{accno}--$ref->{accdescription}"){
	   if ($groupbreak ne 'none'){
	      for (@column_index){ $column_data{$_} = rpt_txt('&nbsp;') }
	      $column_data{debit} = qq|<th align=right>|. $form->format_amount(\%myconfig, $debit_subtotal * -1, $form->{precision}, "0") . qq|</th>|;
	      $column_data{credit} = qq|<th align=right>|. $form->format_amount(\%myconfig, $credit_subtotal, $form->{precision}, "0") . qq|</th>|;
	      $column_data{balance} = qq|<th align=right>|. $form->format_amount(\%myconfig, $balance * -1, $form->{precision}, "0") . qq|</th>|;
	      print "<tr valign=top class=listsubtotal>";
	      for (@column_index) { print "\n$column_data{$_}" }
	      print "</tr>";
	   }
	   $groupbreak = "$ref->{accno}--$ref->{accdescription}";
	   print qq|<tr valign=top>|;
	   print qq|<th align=left colspan=7><br />|.$locale->text('Account') . qq| $groupbreak</th>|;
	   print qq|</tr>|;

   	   # print header
   	   print qq|<tr class=listheading>|;
   	   for (@column_index) { print "\n$column_header{$_}" }
   	   print qq|</tr>|; 

	   $debit_subtotal = 0; $credit_subtotal = 0; $balance = 0;
	   if ($form->{fromdate}){
   	      my $openingquery = qq|
		SELECT SUM(amount) 
		FROM acc_trans
		WHERE chart_id = (SELECT id FROM chart WHERE accno = '$ref->{accno}')
		AND transdate < '$form->{fromdate}'
	     |;
	     ($balance) = $dbh->selectrow_array($openingquery);
	     if ($balance != 0){
	        for (@column_index){ $column_data{$_} = rpt_txt('&nbsp;') }
   		$column_data{debit} 	= rpt_dec(0, $form->{precision}, '0');
   		$column_data{credit} 	= rpt_dec(0, $form->{precision}, '0');
   		$column_data{balance} 	= rpt_dec(0 - $balance, $form->{precision}, '0');

		# print footer
		print "<tr valign=top class=listrow0>";
		for (@column_index) { print "\n$column_data{$_}" }
		print "</tr>";
	     }
	   }
        }
	my $script;
        if ($ref->{module} eq 'ar'){
	   $script = ($ref->{invoice}) ? 'is.pl' : 'ar.pl';
	} elsif ($ref->{module} eq 'ap') {
	   $script = ($ref->{invoice}) ? 'ir.pl' : 'ap.pl';
	} else {
           $script = 'gl.pl';
        }
	  
   	$link = qq|$script?action=edit&id=$ref->{id}&path=$form->{path}&login=$form->{login}&callback=$form->{callback}|;
	$column_data{no}   		= rpt_txt($no);
   	$column_data{transdate}		= rpt_txt($ref->{transdate});
   	$column_data{reference} 	= rpt_txt($ref->{reference}, $link);
   	$column_data{description} 	= rpt_txt($ref->{description});
   	$column_data{name} 		= rpt_txt($ref->{name});
   	$column_data{source}    	= rpt_txt($ref->{source});
	if ($ref->{amount} > 0){
  	  $column_data{debit}    	= rpt_dec(0, $form->{precision}, '0');
   	  $column_data{credit}    	= rpt_dec($ref->{amount}, $form->{precision}, '0');
	} else {
  	  $column_data{debit}    	= rpt_dec(0 - $ref->{amount}, $form->{precision}, '0');
   	  $column_data{credit}    	= rpt_dec(0, $form->{precision}, '0');
	}
	$balance += $ref->{amount};
	$column_data{balance} 		= rpt_dec($balance * -1, $form->{precision}, '0');

	print "<tr valign=top class=listrow$i>";
	for (@column_index) { print "\n$column_data{$_}" }
	print "</tr>";
	$i++; $i %= 2; $no++;

	$debit_subtotal += $ref->{amount} if $ref->{amount} < 0;
	$credit_subtotal += $ref->{amount} if $ref->{amount} > 0;
	$debit_total += $ref->{amount} if $ref->{amount} < 0;
	$credit_total += $ref->{amount} if $ref->{amount} > 0;
   }

   # prepare data for footer
   for (@column_index) { $column_data{$_} = rpt_txt('&nbsp;') }

   # subtotal for last group
   $column_data{debit} = qq|<th align=right>|. $form->format_amount(\%myconfig, $debit_subtotal * -1, $form->{precision}, "0") . qq|</th>|;
   $column_data{credit} = qq|<th align=right>|. $form->format_amount(\%myconfig, $credit_subtotal, $form->{precision}, "0") . qq|</th>|;
   $column_data{balance} = qq|<th align=right>|. $form->format_amount(\%myconfig, $balance * -1, $form->{precision}, "0") . qq|</th>|;

   print "<tr valign=top class=listsubtotal>";
   for (@column_index) { print "\n$column_data{$_}" }
   print "</tr>";

   $column_data{debit} = qq|<th align=right>|. $form->format_amount(\%myconfig, $debit_total * -1, $form->{precision}, "0") . qq|</th>|;
   $column_data{credit} = qq|<th align=right>|. $form->format_amount(\%myconfig, $credit_total, $form->{precision}, "0") . qq|</th>|;
   $column_data{balance} = rpt_txt('&nbsp;');

   # grand totals
   print "<tr valign=top class=listtotal>";
   for (@column_index) { print "\n$column_data{$_}" }
   print "</tr>";

   print qq|</table>|;
   $sth->finish;
   $dbh->disconnect;
}

#===================================
#
# Audit Trail Report
#
#==================================
#-------------------------------
sub audit_search {
   $form->{title} = $locale->text('Audit Trail Report');
   &print_title;
   &start_form;
   &start_table;

   &bld_employee;

   &print_text('trans_id', $locale->text('Trans ID'), 15);
   &print_text('tablename', $locale->text('Table'), 15);
   &print_text('reference', $locale->text('Reference'), 15);
   &print_text('formname', $locale->text('Form'), 15);
   &print_text('formaction', $locale->text('Action'), 15);
   &print_date('fromtransdate', $locale->text('From Trans Date'));
   &print_date('totransdate', $locale->text('To Trans Date'));
   &print_select('employee', $locale->text('Employee'));
 
   print qq|<tr><th align=right>| . $locale->text('Include in Report') . qq|</th><td>|;

   &print_checkbox('l_no', $locale->text('No.'), '', '<br>');
   &print_checkbox('l_trans_id', $locale->text('Trans ID'), 'checked', '<br>');
   &print_checkbox('l_tablename', $locale->text('Table'), 'checked', '<br>');
   &print_checkbox('l_reference', $locale->text('Reference'), 'checked', '<br>');
   &print_checkbox('l_formname', $locale->text('Form'), 'checked', '<br>');
   &print_checkbox('l_action', $locale->text('Action'), 'checked', '<br>');
   &print_checkbox('l_transdate', $locale->text('Trans Date'), 'checked', '<br>');
   &print_checkbox('l_name', $locale->text('Employee'), 'checked', '<br>');
   &print_checkbox('l_csv', $locale->text('CSV'), '', '<br>');
   #&print_checkbox('l_sql', $locale->text('SQL'), '', '<br>');

   print qq|</td></tr>|;
   &end_table;
   print('<hr size=3 noshade>');
   $form->{nextsub} = 'audit_list';
   &print_hidden('nextsub');
   &add_button($locale->text('Continue'));
   &end_form;
}

#-------------------------------
sub audit_list {
  # callback to report list
   my $callback = qq|$form->{script}?action=audit_list|;
   for (qw(path login sessionid)) { $callback .= "&$_=$form->{$_}" }

   &split_combos('employee');
   $form->{employee_id} *= 1;
   $tablename = lc $form->{tablename};
   $reference = $form->like(lc $form->{reference});
   $formname = lc $form->{formname};
   $formaction = lc $form->{formaction};
   
   my $where = qq| (1 = 1)|;
   $where .= qq| AND (a.trans_id = $form->{trans_id})| if $form->{trans_id};
   $where .= qq| AND (a.tablename = '$tablename')| if $form->{tablename};
   $where .= qq| AND (a.LOWER(reference) LIKE '$reference')| if $form->{reference};
   $where .= qq| AND (a.formname = '$formname')| if $form->{formname};
   $where .= qq| AND (a.action = '$formaction')| if $form->{formaction};
   $where .= qq| AND (a.transdate >= '$form->{fromtransdate}')| if $form->{fromtransdate};
   $where .= qq| AND (a.transdate <= '$form->{totransdate}')| if $form->{totransdate};
   $where .= qq| AND (a.employee_id = $form->{employee_id})| if $form->{employee};

   @columns = qw(trans_id tablename reference formname action transdate employee_id);
   # if this is first time we are running this report.
   $form->{sort} = 'tablename' if !$form->{sort};
   $form->{oldsort} = 'none' if !$form->{oldsort};
   $form->{direction} = 'ASC' if !$form->{direction};
   @columns = $form->sort_columns(@columns);

   my %ordinal = (	trans_id => 1,
			tablename => 2,
			reference => 3,
			formname => 4,
			action => 5,
			transdate => 6,
			name => 7
   );
   my $sort_order = $form->sort_order(\@columns, \%ordinal);

   # No. columns should always come first
   splice @columns, 0, 0, 'no';

   # Select columns selected for report display
   foreach $item (@columns) {
     if ($form->{"l_$item"} eq "Y") {
       push @column_index, $item;

       # add column to href and callback
       $callback .= "&l_$item=Y";
     }
   }
   $callback .= "&l_subtotal=$form->{l_subtotal}";
   my $href = $callback;
   $form->{callback} = $form->escape($callback,1);

   $query = qq|SELECT 
		a.trans_id, 
		a.tablename, 
		a.reference, 
		a.formname,
		a.action,
		a.transdate,
		e.name
		FROM audittrail a
		LEFT JOIN employee e ON (e.id = a.employee_id)
		WHERE $where
		ORDER BY $form->{sort} $form->{direction}|;
		#ORDER BY $sort_order|;

   # store oldsort/direction information
   $href .= "&direction=$form->{direction}&oldsort=$form->{sort}";

   $column_header{no}   		= rpt_hdr('no', $locale->text('No.'));
   $column_header{trans_id} 		= rpt_hdr('trans_id', $locale->text('Trans ID'), $href);
   $column_header{tablename} 		= rpt_hdr('tablename', $locale->text('Table'), $href);
   $column_header{reference}  		= rpt_hdr('reference', $locale->text('Reference'), $href);
   $column_header{formname}  		= rpt_hdr('formname', $locale->text('Form'), $href);
   $column_header{action}  		= rpt_hdr('action', $locale->text('Action'), $href);
   $column_header{transdate}  		= rpt_hdr('transdate', $locale->text('Date'), $href);
   $column_header{name}  		= rpt_hdr('name', $locale->text('Employee'), $href);

   $form->error($query) if $form->{l_sql};
   $dbh = $form->dbconnect(\%myconfig);
   my %defaults = $form->get_defaults($dbh, \@{['precision', 'company']});
   for (keys %defaults) { $form->{$_} = $defaults{$_} }

   if ($form->{l_csv} eq 'Y'){
	&export_to_csv($dbh, $query, 'audit_trail');
	exit;
   }
   $sth = $dbh->prepare($query);
   $sth->execute || $form->dberror($query);

   $form->{title} = $locale->text('Audit Trail');
   &print_title;
   &print_criteria('tablename', $locale->text('Table'));
   &print_criteria('reference', $locale->text('Reference'));
   &print_criteria('formname', $locale->text('Form'));
   &print_criteria('formaction', $locale->text('Action'));
   &print_criteria('fromtransdate', $locale->text('From'));
   &print_criteria('totransdate', $locale->text('To'));
   &print_criteria('employee_name', $locale->text('Employee'));

   print qq|<table width=100%><tr class=listheading>|;
   # print header
   for (@column_index) { print "\n$column_header{$_}" }
   print qq|</tr>|; 

   # print data
   my $i = 1; my $no = 1;
   my $groupbreak = 'none';
   while (my $ref = $sth->fetchrow_hashref(NAME_lc)){
   	$form->{link} = qq|$form->{script}?action=edit&id=$ref->{id}&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}&callback=$form->{callback}|;

	$column_data{no}   		= rpt_txt($no);
   	$column_data{trans_id}		= rpt_txt($ref->{trans_id});
   	$column_data{tablename}		= rpt_txt($ref->{tablename});
   	$column_data{reference} 	= rpt_txt($ref->{reference});
   	$column_data{formname}    	= rpt_txt($ref->{formname});
   	$column_data{action}   		= rpt_txt($ref->{action});
   	$column_data{transdate}    	= rpt_txt($ref->{transdate});
   	$column_data{name}    		= rpt_txt($ref->{name});

	print "<tr valign=top class=listrow$i>";
	for (@column_index) { print "\n$column_data{$_}" }
	print "</tr>";
	$i++; $i %= 2; $no++;

   }
   print qq|</table>|;

   $sth->finish;
   $dbh->disconnect;
}

#===================================
#
# Income statement by project
#
#==================================
#-------------------------------
sub income_statement {
   $form->{title} = $locale->text('Income Statement');
   $form->header;
   print qq|
<body>
<table width=100%><tr><th class=listtop>$form->{title}</th></tr></table> <br />
<form method=post action='$form->{script}'>

<table>
<tr>
  <th align=right>|.$locale->text('From').qq|</th><td><input name=datefrom size=11 title='$myconfig{dateformat}'></td>
</tr><tr>
  <th align=right>|.$locale->text('To').qq|</th><td><input name=dateto size=11 title='$myconfig{dateformat}'></td>
</tr>
<tr>
<th>|.$locale->text('Include').qq|:</th>
<td>|;

   my $dbh = $form->dbconnect(\%myconfig);
   my $query = qq|SELECT id, projectnumber FROM project ORDER BY projectnumber|;
   my $sth = $dbh->prepare($query) || $form->dberror($query);
   $sth->execute || $form->dberror($query);
   while (my $ref = $sth->fetchrow_hashref(NAME_lc)){
      print qq|<input name=p_$ref->{id} type=checkbox class=checkbox value=1 checked>$ref->{projectnumber}<br>\n|;
   }

print qq|
</td></tr>
</table>
<hr>
<input type=submit class=submit name=action value="|.$locale->text('Continue').qq|">|;
   $form->{nextsub} = 'generate_income_statement';
   $form->hide_form(qw(title path nextsub login));
   print qq|
</form>
</body>
|;

}

#-------------------------------
sub generate_income_statement {
  $form->header;
  print qq|<body><table width=100%><tr><th class=listtop>$form->{title}</th></tr></table><br />|;
  print qq|<h4>INCOME STATEMENT</h4>|;
  print qq|<h4>for Period</h4>|;
  print qq|<h4>From $form->{datefrom}</h4>| if $form->{datefrom};
  print qq|<h4>To $form->{dateto}</h4>| if $form->{dateto};
  my $dbh = $form->dbconnect(\%myconfig);
  my $query = qq|SELECT id, projectnumber FROM project ORDER BY projectnumber|;
  my $sth = $dbh->prepare($query) || $form->dberror($query);
  $sth->execute || $form->dberror($query);

  my %projects;
  my $is_query = qq|SELECT c.accno, c.description, c.category, charttype,\n|;
  while (my $ref = $sth->fetchrow_hashref(NAME_lc)){
     if ($form->{"p_$ref->{id}"}){
	$projects{"p_$ref->{id}"} = $ref->{projectnumber};
        $is_query .= qq|SUM(CASE WHEN ac.project_id = $ref->{id} THEN ac.amount ELSE 0 END) AS p_$ref->{id},\n|
     }
  }
  $sth->finish;
  chop $is_query;
  chop $is_query;
  my $where = qq|c.category IN ('I', 'E')|;
  my $ywhere = qq| 1 = 1 |;
  if ($form->{datefrom}){
    $where .= qq| AND ac.transdate >= '$form->{datefrom}'|;
    $ywhere .= qq| AND transdate >= '$form->{datefrom}'|;
  }
  if ($form->{dateto}){
    $where .= qq| AND ac.transdate <= '$form->{dateto}'|;
    $ywhere .= qq| AND transdate <= '$form->{dateto}'|;
  }
  $where .= qq| AND ac.trans_id NOT IN (SELECT trans_id FROM yearend WHERE $ywhere)|;

  $is_query .= qq| 
		FROM acc_trans ac
		JOIN chart c ON (c.id = ac.chart_id)
		WHERE $where
		GROUP BY c.accno, c.description, c.category, c.charttype
		ORDER BY c.accno
  |;

  $sth = $dbh->prepare($is_query) || $form->dberror($is_query);
  $sth->execute || $form->dberror($is_query);
  while (my $ref = $sth->fetchrow_hashref(NAME_lc)){
	$form->{$ref->{category}}{$ref->{accno}}{accno} = "$ref->{accno}";
	$form->{$ref->{category}}{$ref->{accno}}{charttype} = "$ref->{charttype}";
	$form->{$ref->{category}}{$ref->{accno}}{category} = "$ref->{category}";
	$form->{$ref->{category}}{$ref->{accno}}{description} = "$ref->{description}";
	for (keys %projects){
	   $form->{$ref->{category}}{$ref->{accno}}{$_} = "$ref->{$_}";
	}
  }
  $sth->finish;

  print qq|
<table>
<tr>
<th>&nbsp;</th><th>&nbsp;</th>
|;

  for (keys %projects){ print qq|<th>$projects{$_}</th>| }
  print qq|
</tr>
|;

  # Print INCOME
  print qq|<tr><td colspan=2><b>INCOME<br><hr width=300 size=5 align=left noshade></b></td></tr>|;
  foreach $accno (sort keys %{ $form->{I} }){
     print qq|<tr>|;
     print qq|<td>$form->{I}{$accno}{accno}</td>|;
     print qq|<td>$form->{I}{$accno}{description}</td>|;
     for (keys %projects){ 
	print qq|<td align=right>| . $form->format_amount(\%myconfig, $form->{I}{$accno}{$_}, 0) . qq|</td>|;
	$form->{I}{$_}{totalincome} += $form->{I}{$accno}{$_};
     }
     print qq|</tr>|;
  }
  print qq|<tr><td colspan=2>&nbsp;</td>|;
  for (keys %projects){ print qq|<td><hr noshade size=1></td>|; }
  print qq|</tr>|;

  print qq|<tr><td colspan=2 align=right><b>TOTAL INCOME</b></td>|;
  for (keys %projects){ print qq|<td align=right>| . $form->format_amount(\%myconfig, $form->{I}{$_}{totalincome}, 0) . qq|</td>|; }
  print qq|</tr>|;

  print qq|<tr><td colspan=2>&nbsp;</td>|;
  for (keys %projects){ print qq|<td><hr noshade size=2></td>|; }
  print qq|</tr>|;

  # Print EXPENSES
  print qq|<tr><td colspan=2><b>EXPENSES<br><hr width=300 size=5 align=left noshade></b></td></tr>|;
  foreach $accno (sort keys %{ $form->{E} }){
     print qq|<tr>|;
     print qq|<td>$form->{E}{$accno}{accno}</td>|;
     print qq|<td>$form->{E}{$accno}{description}</td>|;
     for (keys %projects){ 
	print qq|<td align=right>| . $form->format_amount(\%myconfig, $form->{E}{$accno}{$_} * -1, 0) . qq|</td>|; 
	$form->{E}{$_}{totalexpenses} += $form->{E}{$accno}{$_} * -1;
     }
     print qq|</tr>|;
  }
  print qq|<tr><td colspan=2>&nbsp;</td>|;
  for (keys %projects){ print qq|<td><hr noshade size=1></td>|; }
  print qq|</tr>|;

  print qq|<tr><td colspan=2 align=right><b>TOTAL EXPENSES</b></td>|;
  for (keys %projects){ print qq|<td align=right>| . $form->format_amount(\%myconfig, $form->{E}{$_}{totalexpenses}, 0) . qq|</td>|; }
  print qq|</tr>|;

  print qq|<tr><td colspan=2>&nbsp;</td>|;
  for (keys %projects){ print qq|<td><hr noshade size=2></td>|; }
  print qq|</tr>|;

  print qq|<tr><td colspan=2 align=right><b>INCOME (LOSS)</b></td>|;
  for (keys %projects){ print qq|<td align=right>| . $form->format_amount(\%myconfig, $form->{I}{$_}{totalincome} - $form->{E}{$_}{totalexpenses},0) . qq|</td>|; }
  print qq|</tr>|;

  print qq|<tr><td colspan=2>&nbsp;</td>|;
  for (keys %projects){ print qq|<td><hr noshade size=2></td>|; }
  print qq|</tr>|;
}

#===================================
#
# Sale Qty Summary Report
#
#===================================
#-----------------------------------
sub aa_qty_search {
  $form->get_partsgroup(\%myconfig, { searchitems => 'parts'});
  $form->all_years(\%myconfig);

  if (@{ $form->{all_partsgroup} }) {
    $partsgroup = qq|<option>\n|;

    for (@{ $form->{all_partsgroup} }) { $partsgroup .= qq|<option value="|.$form->quote($_->{partsgroup}).qq|--$_->{id}">$_->{partsgroup}\n| }

    $partsgroup = qq| 
        <th align=right nowrap>|.$locale->text('Group').qq|</th>
	<td><select name=partsgroup>$partsgroup</select></td>
|;

    $l_partsgroup = qq|<input name=l_partsgroup class=checkbox type=checkbox value=Y> |.$locale->text('Group');
  }

  if (@{ $form->{all_years} }) {
    $selectfrom = qq|
        <tr>
 	  <th align=right>|.$locale->text('Include Months').qq|</th>
	  <td colspan=3>
	    <table>
	      <tr>
		<td>
		  <table>
		    <tr>
|;

    for (sort keys %{ $form->{all_month} }) {
      $i = ($_ * 1) - 1;
      if (($i % 3) == 0) {
	$selectfrom .= qq|
		    </tr>
		    <tr>
|;
      }

      $i = $_ * 1;
	
      $selectfrom .= qq|
		      <td nowrap><input name="l_month_$i" class checkbox type=checkbox value=Y checked>&nbsp;|.$locale->text($form->{all_month}{$_}).qq|</td>\n|;
    }
		
    $selectfrom .= qq|
		    </tr>
		  </table>
		</td>
	      </tr>
	    </table>
	  </td>
        </tr>
|;
  } else {
    $form->error($locale->text('No History!'));
  }


   if ($form->{vc} eq 'customer'){
	$form->{title} = $locale->text('Sale Qty Summary');
   } else {
   	$form->{title} = $locale->text('Purchase Qty Summary');
   }
   &print_title;
   &start_form;
   &start_table;

   &print_text('partnumber', $locale->text('Number'), 20);
   &print_text('name', $locale->text('Name'), 30);
   &print_date('fromdate', $locale->text('From'));
   &print_date('todate', $locale->text('To'));

   print qq|<tr>$partsgroup</tr>|;
   print $selectfrom;
  
   print qq|<tr><th align=right>| . $locale->text('Include in Report') . qq|</th><td>|;

   &print_checkbox('l_no', $locale->text('No.'), '', '<br>');
   &print_checkbox('l_partnumber', $locale->text('Number'), 'checked', '<br>');
   &print_checkbox('l_category', $locale->text('Category'), 'checked', '<br>');
   &print_checkbox('l_description', $locale->text('Description'), 'checked', '<br>');
   &print_checkbox('l_onhand', $locale->text('Onhand'), 'checked', '<br>');
   &print_checkbox('l_lastcost', $locale->text('Last Cost'), 'checked', '<br>');
   &print_checkbox('l_extended', $locale->text('Extended'), 'checked', '<br>');
   #&print_checkbox('l_subtotal', $locale->text('Subtotal'), '', '<br>');
   &print_checkbox('l_csv', $locale->text('CSV'), '', '<br>');
   &print_checkbox('l_allitems', $locale->text('All'), '', '<br>');
   #&print_checkbox('l_sql', $locale->text('SQL'), '');

   print qq|</td></tr>|;
   &end_table;
   print('<hr size=3 noshade>');
   $form->{nextsub} = 'aa_qty_list';
   &print_hidden('nextsub');
   &print_hidden('vc');
   &add_button($locale->text('Continue'));
   &end_form;
}

#-------------------------------
sub aa_qty_list {
  # callback to report list
   my $callback = qq|$form->{script}?action=aa_qty_list|;
   for (qw(path login sessionid)) { $callback .= "&$_=$form->{$_}" }

   &split_combos('partsgroup,warehouse');
   $form->{partsgroup_id} *= 1;

   my $aa = ($form->{vc} eq 'customer') ? 'ar' : 'ap';
   my $AA = ($form->{vc} eq 'customer') ? 'AR' : 'AP';
   my $sign = ($form->{vc} eq 'customer') ? 1 : -1;

   $partnumber = $form->like(lc $form->{partnumber});
   $name = $form->like(lc $form->{name});
   $description = $form->like(lc $form->{description});
   
   my $where = qq| (1 = 1)|;
   $where .= qq| AND (aa.transdate >= '$form->{fromdate}')| if $form->{fromdate};
   $where .= qq| AND (aa.transdate <= '$form->{todate}')| if $form->{todate};
   $where .= qq| AND (p.partsgroup_id = $form->{partsgroup_id})| if $form->{partsgroup};
   $where .= qq| AND (LOWER(p.partnumber) LIKE '$partnumber')| if $form->{partnumber};
   $where .= qq| AND (LOWER(p.description) LIKE '$description')| if $form->{description};
   $where .= qq| AND (LOWER(cv.name) LIKE '$name')| if $form->{name};

   @columns = qw(partnumber category description);
   splice @columns, 0, 0, 'no'; # No. columns should always come first
   # Select columns selected for report display
   foreach $item (@columns) {
     if ($form->{"l_$item"} eq "Y") {
       push @column_index, $item;

       # add column to href and callback
       $callback .= "&l_$item=Y";
     }
   }

   my $months_count = 0;
   for (1 .. 12) {
     if ($form->{"l_month_$_"}) {
       $callback .= qq|&l_month_$_=$form->{"l_month_$_"}|;
       push @column_index, $_;
       $month{$_} = 1;
       $months_count++;
     }
   }

   @columns2 = qw(onhand lastcost extended);
   foreach $item (@columns2) {
     if ($form->{"l_$item"} eq "Y") {
       push @column_index, $item;

       # add column to href and callback
       $callback .= "&l_$item=Y";
     }
   }
   push @columns, @columns2;

   # if this is first time we are running this report.
   $form->{sort} = "partnumber" if !$form->{sort};
   $form->{oldsort} = 'none' if !$form->{oldsort};
   $form->{direction} = 'ASC' if !$form->{direction};
   @columns = $form->sort_columns(@columns);

   my %ordinal = (	
			partnumber => 1,
			category => 2,
			description => 3,
			onhand => $months_count + 4,
			lastcost => $months_count + 5,
			extended => $months_count + 6
   );
   my $sort_order = $form->sort_order(\@columns, \%ordinal);

   $callback .= "&l_subtotal=$form->{l_subtotal}";
   $callback .= "&vc=$form->{vc}";
   my $href = $callback;
   $form->{callback} = $form->escape($callback,1);

   $query = qq|SELECT
		p.id,
		p.partnumber,
		substring(p.partnumber from 5) as category,
		p.description,
		p.onhand,
		p.lastcost,
		p.onhand * p.lastcost AS extended,
		EXTRACT (MONTH FROM aa.transdate) AS month,
		SUM(i.qty) AS qty

		FROM invoice i
		JOIN $aa aa ON (aa.id = i.trans_id)
		JOIN customer cv ON (cv.id = aa.customer_id)
		JOIN parts p ON (p.id = i.parts_id)

		WHERE $where
		GROUP BY 1,2,3,4,5,6,7,8
		ORDER BY $form->{sort} $form->{direction}|;
		#ORDER BY $sort_order|;

   $form->error($query) if $form->{l_sql};
   $dbh = $form->dbconnect(\%myconfig);
   my %defaults = $form->get_defaults($dbh, \@{['precision', 'company']});
   for (keys %defaults) { $form->{$_} = $defaults{$_} }

   $sth = $dbh->prepare($query);
   $sth->execute || $form->dberror($query);

   my %parts;
   if ($form->{l_allitems}){
      my $allitemsquery = qq|
	SELECT 
	  p.id,
	  p.partnumber,
	  substring(p.partnumber from 5) as category,
	  p.description,
	  p.onhand,
	  p.lastcost,
	  p.onhand * p.lastcost AS extended
	FROM parts p
	ORDER BY 1|;
      my $allitemssth = $dbh->prepare($allitemsquery);
      $allitemssth->execute;
      while (my $ref = $allitemssth->fetchrow_hashref(NAME_lc)){
	$parts{$ref->{id}} = $ref;
      }
   }
   while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
     if (exists $parts{$ref->{id}}) {
       $parts{$ref->{id}}->{$ref->{month}} = $ref->{qty};
       $parts{$ref->{id}}->{qty} += $ref->{qty};
     } else {
       $ref->{$ref->{month}} = $ref->{qty};
       $parts{$ref->{id}} = $ref;
     }
   }
   $sth->finish;

   if ($form->{sort} =~ /(onhand|lastcost|extended)/){
     # sort numberically
     if ($form->{direction} eq 'ASC'){
        for (sort { $parts{$a}->{$form->{sort}} <=> $parts{$b}->{$form->{sort}} } keys %parts) {
           push @{ $form->{parts} }, $parts{$_};
        }
     } else {
        for (sort { $parts{$b}->{$form->{sort}} <=> $parts{$a}->{$form->{sort}} } keys %parts) {
           push @{ $form->{parts} }, $parts{$_};
        }
     }
   } else {
     # sort alphabetically
     for (sort { $parts{$a}->{$form->{sort}} cmp $parts{$b}->{$form->{sort}} } keys %parts) {
        push @{ $form->{parts} }, $parts{$_};
     }
   }
   # store oldsort/direction information
   $href .= "&direction=$form->{direction}&oldsort=$form->{sort}";

   $column_header{no}   		= rpt_hdr('no', $locale->text('No.'));
   $column_header{partnumber} 		= rpt_hdr('partnumber', $locale->text('Number'), $href);
   $column_header{category} 		= rpt_hdr('category', $locale->text('Category'), $href);
   $column_header{description} 		= rpt_hdr('description', $locale->text('Description'), $href);
   $column_header{onhand} 		= rpt_hdr('onhand', $locale->text('Onhand'), $href);
   $column_header{lastcost} 		= rpt_hdr('lastcost', $locale->text('Last Cost'), $href);
   $column_header{extended} 		= rpt_hdr('extended', $locale->text('Extended'), $href);

   $form->all_years(\%myconfig);
   for (1 .. 12) { $column_header{$_} = qq|<th class=listheading nowrap>|.$locale->text($locale->{SHORT_MONTH}[$_-1]).qq|</th>| }

   if ($form->{l_csv} eq 'Y'){
	&ref_to_csv('parts', "qty_summary", \@column_index);
	exit;
   }

   if ($form->{vc} eq 'customer'){
	$form->{title} = $locale->text('Sale Qty Summary');
   } else {
   	$form->{title} = $locale->text('Purchase Qty Summary');
   }
   &print_title;

   # Print report criteria
   &print_criteria('partnumber', $locale->text('Number'));
   &print_criteria('name', $locale->text('Name'));
   &print_criteria('description', $locale->text('Description'));
   &print_criteria('fromdate', $locale->text('From'));
   &print_criteria('todate', $locale->text('To'));
   &print_criteria('partsgroup_name', $locale->text('Group'));

   print qq|<table width=100%><tr class=listheading>|;
   # print header
   for (@column_index) { print "\n$column_header{$_}" }
   print qq|</tr>|; 

   # Subtotal and total variables
   my $balance_subtotal = 0;
   my $onhand_total = 0;
   my %extended_total = 0;

   # print data
   my $i = 1; my $no = 1;
   my $groupbreak = 'none';

   foreach $ref (@{ $form->{parts} }) {
   	$form->{link} = qq|$form->{script}?action=edit&id=$ref->{id}&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}&callback=$form->{callback}|;
	$groupbreak = $ref->{$form->{sort}} if $groupbreak eq 'none';
	if ($form->{l_subtotal}){
	   if ($groupbreak ne $ref->{$form->{sort}}){
		$groupbreak = $ref->{$form->{sort}};
		# prepare data for footer

   		$column_data{no}   			= rpt_txt('&nbsp;');
   		$column_data{partnumber}  		= rpt_txt('&nbsp;');
   		$column_data{description}  		= rpt_txt('&nbsp;');
   		$column_data{jan} 			= rpt_dec('&nbsp;');

		# print footer
		print "<tr valign=top class=listsubtotal>";
		for (@column_index) { print "\n$column_data{$_}" }
		print "</tr>";

		$balance_subtotal = 0;
	   }
	}

	$column_data{no}   		= rpt_txt($no);
   	$column_data{partnumber}	= rpt_txt($ref->{partnumber});
   	$column_data{category}		= rpt_txt($ref->{category});
   	$column_data{description}	= rpt_txt($ref->{description}, $form->{link});
   	$column_data{onhand}		= rpt_dec($ref->{onhand},0);
   	$column_data{lastcost}		= rpt_dec($ref->{lastcost},2);
   	$column_data{extended}		= rpt_dec($ref->{extended},2);

	for (1 .. 12){
	    $column_data{$_} = rpt_dec($ref->{$_},0);
	    $total{$_} += $ref->{$_};
        }

	print "<tr valign=top class=listrow$i>";
	for (@column_index) { print "\n$column_data{$_}" }
	print "</tr>";
	$i++; $i %= 2; $no++;

	$onhand_total += $ref->{onhand};
	$extended_total += $ref->{extended};
   }

   # prepare data for footer
   $column_data{no}   			= rpt_txt('&nbsp;');
   $column_data{partnumber}  		= rpt_txt('&nbsp;');
   $column_data{category}  		= rpt_txt('&nbsp;');
   $column_data{description}   		= rpt_txt('&nbsp;');
   $column_data{lastcost}   		= rpt_txt('&nbsp;');

   if ($form->{l_subtotal}){
	# print last subtotal
	print "<tr valign=top class=listsubtotal>";
	for (@column_index) { print "\n$column_data{$_}" }
	print "</tr>";
   }

   # grand total
   for (1 .. 12){
      $column_data{$_} = rpt_dec($total{$_},0);
      $total{$_} += $ref->{$_};
   }

   $column_data{onhand}   		= rpt_dec($onhand_total,0);
   $column_data{extended}   		= rpt_dec($extended_total,2);

   # print footer
   print "<tr valign=top class=listtotal>";
   for (@column_index) { print "\n$column_data{$_}" }
   print "</tr>";

   print qq|</table>|;
   $sth->finish;
   $dbh->disconnect;
}


#===================================
#
# Customer / Vendor Balances Report
#
#==================================
#-------------------------------
sub vc_search {
   if ($form->{vc} eq 'customer'){
	$form->{title} = $locale->text('Customer Balances');
   } else {
   	$form->{title} = $locale->text('Vendor Balances');
   }
   &print_title;


   &start_form;
   &start_table;

   &print_text('name', $locale->text('Name'), 30);
   &print_date('todate', $locale->text('Upto Date'));
   

   print qq|<tr><th align=right>| . $locale->text('Include in Report') . qq|</th><td>|;

   &print_checkbox('l_no', $locale->text('No.'), '', '<br>');
   &print_checkbox("l_$form->{vc}number", $locale->text('Number'), 'checked', '<br>');
   &print_checkbox('l_name', $locale->text('Name'), 'checked', '<br>');
   &print_checkbox('l_balance', $locale->text('Balance'), 'checked', '<br>');
   #&print_checkbox('l_subtotal', $locale->text('Subtotal'), '', '<br>');
   &print_checkbox('l_csv', $locale->text('CSV'), '', '<br>');
   &print_checkbox('l_sql', $locale->text('SQL'), '');

   print qq|</td></tr>|;
   &end_table;
   print('<hr size=3 noshade>');
   $form->{nextsub} = 'vc_list';
   &print_hidden('nextsub');
   &print_hidden('vc');
   &add_button($locale->text('Continue'));
   &end_form;
}

#-------------------------------
sub vc_list {
  # callback to report list
   my $callback = qq|$form->{script}?action=vc_list|;
   for (qw(path login sessionid)) { $callback .= "&$_=$form->{$_}" }

   #&split_combos('department,from_warehouse,to_warehouse,expense_accno');
   #$form->{department_id} *= 1;
   my $aa = ($form->{vc} eq 'customer') ? 'ar' : 'ap';
   my $AA = ($form->{vc} eq 'customer') ? 'AR' : 'AP';
   my $sign = ($form->{vc} eq 'customer') ? 1 : -1;

   $vcnumber = $form->like(lc $form->{"$form->{vc}number"});
   $name = $form->like(lc $form->{name});
   
   my $where = qq| (1 = 1)|;
   $where .= qq| AND (ac.transdate <= '$form->{todate}')| if $form->{todate};
   $where .= qq| AND (LOWER("$form->{vc}number") LIKE '$vcnumber')| if $form->{"$form->{vc}number"};
   $where .= qq| AND (LOWER(name) LIKE '$name')| if $form->{name};
   $where .= qq| AND (c.link = '$AA')|;

   @columns = ("id", "$form->{vc}number", "name", "balance");
   # if this is first time we are running this report.
   $form->{sort} = "$form->{vc}number" if !$form->{sort};
   $form->{oldsort} = 'none' if !$form->{oldsort};
   $form->{direction} = 'ASC' if !$form->{direction};
   @columns = $form->sort_columns(@columns);

   my %ordinal = (	id => 1,
			"$form->{vc}number" => 2,
			name => 3,
			balance => 4
   );
   my $sort_order = $form->sort_order(\@columns, \%ordinal);

   # No. columns should always come first
   splice @columns, 0, 0, 'no';

   # Select columns selected for report display
   foreach $item (@columns) {
     if ($form->{"l_$item"} eq "Y") {
       push @column_index, $item;

       # add column to href and callback
       $callback .= "&l_$item=Y";
     }
   }
   $callback .= "&l_subtotal=$form->{l_subtotal}";
   $callback .= "&vc=$form->{vc}";
   my $href = $callback;
   $form->{callback} = $form->escape($callback,1);

   $query = qq|SELECT 
		ct.id, 
		ct.$form->{vc}number, 
		ct.name, 
		(SUM(0 - ac.amount) * $sign) AS balance

		FROM $form->{vc} ct
		JOIN $aa aa ON (ct.id = aa.$form->{vc}_id)
		JOIN acc_trans ac ON (aa.id = ac.trans_id)
		JOIN chart c ON (c.id = ac.chart_id)

		WHERE $where
		GROUP BY 1,2,3
		ORDER BY $form->{sort} $form->{direction}|;
		#ORDER BY $sort_order|;

   # store oldsort/direction information
   $href .= "&direction=$form->{direction}&oldsort=$form->{sort}";

   $column_header{no}   		= rpt_hdr('no', $locale->text('No.'));
   $column_header{"$form->{vc}number"} 	= rpt_hdr("$form->{vc}number", $locale->text('Number'), $href);
   $column_header{name}    		= rpt_hdr('name', $locale->text('Name'), $href);
   $column_header{balance}  		= rpt_hdr('balance', $locale->text('Balance'), $href);

   $form->error($query) if $form->{l_sql};
   $dbh = $form->dbconnect(\%myconfig);
   my %defaults = $form->get_defaults($dbh, \@{['precision', 'company']});
   for (keys %defaults) { $form->{$_} = $defaults{$_} }

   if ($form->{l_csv} eq 'Y'){
	&export_to_csv($dbh, $query, "$form->{vc}_balances");
	exit;
   }
   $sth = $dbh->prepare($query);
   $sth->execute || $form->dberror($query);


   if ($form->{vc} eq 'customer'){
   	$form->{title} = $locale->text('Customer Balances');
   } else {
   	$form->{title} = $locale->text('Vendor Balances');
   }
   &print_title;

   # Print report criteria
   &print_criteria('name', $locale->text('Name'));

   print qq|<table width=100%><tr class=listheading>|;
   # print header
   for (@column_index) { print "\n$column_header{$_}" }
   print qq|</tr>|; 

   # Subtotal and total variables
   my $balance_subtotal = 0;
   my $balance_total = 0;

   # print data
   my $i = 1; my $no = 1;
   my $groupbreak = 'none';
   while (my $ref = $sth->fetchrow_hashref(NAME_lc)){
   	$form->{link} = qq|ct.pl?action=edit&db=$form->{vc}&id=$ref->{id}&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}&callback=$form->{callback}|;
	$groupbreak = $ref->{$form->{sort}} if $groupbreak eq 'none';
	if ($form->{l_subtotal}){
	   if ($groupbreak ne $ref->{$form->{sort}}){
		$groupbreak = $ref->{$form->{sort}};
		# prepare data for footer

   		$column_data{no}   			= rpt_txt('&nbsp;');
   		$column_data{"$form->{vc}number"}  	= rpt_txt('&nbsp;');
   		$column_data{name}    			= rpt_txt('&nbsp;');
   		$column_data{balance} 			= rpt_dec('&nbsp;');

		# print footer
		print "<tr valign=top class=listsubtotal>";
		for (@column_index) { print "\n$column_data{$_}" }
		print "</tr>";

		$balance_subtotal = 0;
	   }
	}

	$column_data{no}   			= rpt_txt($no);
   	$column_data{"$form->{vc}number"}	= rpt_txt($ref->{"$form->{vc}number"});
   	$column_data{name} 			= rpt_txt($ref->{name}, $form->{link});
   	$column_data{balance}    		= rpt_dec($ref->{balance});

	print "<tr valign=top class=listrow$i>";
	for (@column_index) { print "\n$column_data{$_}" }
	print "</tr>";
	$i++; $i %= 2; $no++;

	$balance_subtotal += $ref->{balance};
	$balance_total += $ref->{balance};
   }

   # prepare data for footer
   $column_data{no}   			= rpt_txt('&nbsp;');
   $column_data{"$form->{vc}number"}  	= rpt_txt('&nbsp;');
   $column_data{name}    		= rpt_txt('&nbsp;');
   $column_data{balance} 		= rpt_txt('&nbsp;');

   if ($form->{l_subtotal}){
	# print last subtotal
	print "<tr valign=top class=listsubtotal>";
	for (@column_index) { print "\n$column_data{$_}" }
	print "</tr>";
   }

   # grand total
   $column_data{balance} = rpt_dec($balance_total);

   # print footer
   print "<tr valign=top class=listtotal>";
   for (@column_index) { print "\n$column_data{$_}" }
   print "</tr>";

   print qq|</table>|;
   $sth->finish;
   $dbh->disconnect;
}



#===================================
#
# Customer / Vendor Activity Report
#
#==================================
#-------------------------------
sub vcactivity_search {
   if ($form->{vc} eq 'customer'){
	$form->{title} = $locale->text('Customer Activity');
   } else {
   	$form->{title} = $locale->text('Vendor Activity');
   }
   &print_title;
   &start_form;
   &start_table;

   &print_text("$form->{vc}number", $locale->text('Number'), 10);
   &print_text('name', $locale->text('Name'), 30);
   &print_date('todate', $locale->text('Upto Date'));
   
   print qq|<tr><th align=right>| . $locale->text('Include in Report') . qq|</th><td>|;

   &print_checkbox('l_no', $locale->text('No.'), '', '<br>');
   &print_checkbox("l_$form->{vc}number", $locale->text('Number'), 'checked', '<br>');
   &print_checkbox('l_name', $locale->text('Name'), 'checked', '<br>');
   &print_checkbox('l_transdate', $locale->text('Date'), 'checked', '<br>');
   &print_checkbox('l_invnumber', $locale->text('Invoice Number'), 'checked', '<br>');
   &print_checkbox('l_description', $locale->text('Description'), 'checked', '<br>');
   &print_checkbox('l_debit', $locale->text('Debit'), 'checked', '<br>');
   &print_checkbox('l_credit', $locale->text('Credit'), 'checked', '<br>');
   &print_checkbox('l_balance', $locale->text('Balance'), 'checked', '<br>');
   &print_checkbox('l_subtotal', $locale->text('Subtotal'), '', '<br>');
   &print_checkbox('l_csv', $locale->text('CSV'), '', '<br>');
   &print_checkbox('l_sql', $locale->text('SQL'), '');

   print qq|</td></tr>|;
   &end_table;
   print('<hr size=3 noshade>');
   $form->{nextsub} = 'vcactivity_list';
   &print_hidden('nextsub');
   &print_hidden('vc');
   &add_button($locale->text('Continue'));
   &end_form;
}

#-------------------------------
sub vcactivity_list {
  # callback to report list
   my $callback = qq|$form->{script}?action=vcactivity_list|;
   for (qw(path login sessionid)) { $callback .= "&$_=$form->{$_}" }

   #&split_combos('department,from_warehouse,to_warehouse,expense_accno');
   #$form->{department_id} *= 1;
   my $aa = ($form->{vc} eq 'customer') ? 'ar' : 'ap';
   my $AA = ($form->{vc} eq 'customer') ? 'AR' : 'AP';
   my $sign = ($form->{vc} eq 'customer') ? 1 : -1;

   $vcnumber = $form->like(lc $form->{"$form->{vc}number"});
   $name = $form->like(lc $form->{name});
   
   my $where = qq| (1 = 1)|;
   $where .= qq| AND (ac.transdate <= '$form->{todate}')| if $form->{todate};
   $where .= qq| AND (LOWER("$form->{vc}number") LIKE '$vcnumber')| if $form->{"$form->{vc}number"};
   $where .= qq| AND (LOWER(name) LIKE '$name')| if $form->{name};
   $where .= qq| AND (c.link = '$AA')|;

   @columns = ("id", "$form->{vc}number", "name", "transdate", "invnumber", "description", "debit", "credit", "balance");
   # if this is first time we are running this report.
   $form->{sort} = "$form->{vc}number" if !$form->{sort};
   $form->{oldsort} = 'none' if !$form->{oldsort};
   $form->{direction} = 'ASC' if !$form->{direction};
   @columns = $form->sort_columns(@columns);

   my %ordinal = (	id => 1,
			"$form->{vc}number" => 2,
			name => 3,
			transdate => 4,
			invnumber => 5,
			description => 6,
			debit => 7,
			credit => 8,
			balance => 9
   );
   my $sort_order = $form->sort_order(\@columns, \%ordinal);

   # No. columns should always come first
   splice @columns, 0, 0, 'no';

   # Select columns selected for report display
   foreach $item (@columns) {
     if ($form->{"l_$item"} eq "Y") {
       push @column_index, $item;

       # add column to href and callback
       $callback .= "&l_$item=Y";
     }
   }
   for ("l_subtotal", "$form->{vc}number", "name", "todate", "vc"){
	$callback .= qq|&$_=$form->{$_}|;
   }
   my $href = $callback;
   $form->{callback} = $form->escape($callback,1);

   $query = qq|SELECT 
		ct.$form->{vc}number, 
		ct.name, 
		ac.transdate,
		aa.invnumber,
		aa.description,
		CASE WHEN ac.amount * $sign < 0 THEN  0 - ac.amount ELSE 0 END AS debit,
		CASE WHEN ac.amount * $sign > 0 THEN  ac.amount ELSE 0 END AS credit

		FROM $aa aa
		JOIN $form->{vc} ct ON (ct.id = aa.$form->{vc}_id)
		JOIN acc_trans ac ON (aa.id = ac.trans_id)
		JOIN chart c ON (c.id = ac.chart_id)

		WHERE $where
		ORDER BY $form->{sort} $form->{direction}|;
		#ORDER BY $sort_order|;

   # store oldsort/direction information
   $href .= "&direction=$form->{direction}&oldsort=$form->{sort}";

   $column_header{no}   		= rpt_hdr('no', $locale->text('No.'));
   $column_header{"$form->{vc}number"} 	= rpt_hdr("$form->{vc}number", $locale->text('Number'), $href);
   $column_header{name}    		= rpt_hdr('name', $locale->text('Name'), $href);
   $column_header{transdate}    	= rpt_hdr('transdate', $locale->text('Date'), $href);
   $column_header{invnumber}    	= rpt_hdr('invnumber', $locale->text('Invoice Number'), $href);
   $column_header{description}    	= rpt_hdr('description', $locale->text('Description'), $href);
   $column_header{debit}  		= rpt_hdr('debit', $locale->text('Debit'), $href);
   $column_header{credit}  		= rpt_hdr('credit', $locale->text('Credit'), $href);
   $column_header{balance}  		= rpt_hdr('balance', $locale->text('Balance'), $href);

   $form->error($query) if $form->{l_sql};
   $dbh = $form->dbconnect(\%myconfig);
   my %defaults = $form->get_defaults($dbh, \@{['precision', 'company']});
   for (keys %defaults) { $form->{$_} = $defaults{$_} }

   if ($form->{l_csv} eq 'Y'){
	&export_to_csv($dbh, $query, "$form->{vc}_activity");
	exit;
   }
   $sth = $dbh->prepare($query);
   $sth->execute || $form->dberror($query);

   if ($form->{vc} eq 'customer'){
   	$form->{title} = $locale->text('Customer Activity');
   } else {
   	$form->{title} = $locale->text('Vendor Activity');
   }
   &print_title;

   # Print report criteria
   &print_criteria('name', $locale->text('Name'));

   print qq|<table width=100%><tr class=listheading>|;
   # print header
   for (@column_index) { print "\n$column_header{$_}" }
   print qq|</tr>|; 

   # Subtotal and total variables
   my $debit_subtotal = 0;
   my $credit_subtotal = 0;

   my $debit_total = 0;
   my $credit_total = 0;

   my $balance_subtotal = 0;
   my $balance_total = 0;

   # print data
   my $i = 1; my $no = 1;
   my $groupbreak = 'none';
   while (my $ref = $sth->fetchrow_hashref(NAME_lc)){
   	$form->{link} = qq|$form->{script}?action=edit&id=$ref->{id}&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}&callback=$form->{callback}|;
	$groupbreak = $ref->{$form->{sort}} if $groupbreak eq 'none';
	if ($form->{l_subtotal}){
	   if ($groupbreak ne $ref->{$form->{sort}}){
		$groupbreak = $ref->{$form->{sort}};
		# prepare data for footer

   		$column_data{no}   			= rpt_txt('&nbsp;');
   		$column_data{"$form->{vc}number"}  	= rpt_txt('&nbsp;');
   		$column_data{name}    			= rpt_txt('&nbsp;');
   		$column_data{transdate}  		= rpt_txt('&nbsp;');
   		$column_data{invnumber} 		= rpt_txt('&nbsp;');
   		$column_data{description} 		= rpt_txt('&nbsp;');
   		$column_data{debit} 			= rpt_dec($debit_subtotal);
   		$column_data{credit} 			= rpt_dec($credit_subtotal);
   		$column_data{balance} 			= rpt_dec('&nbsp;');

		# print footer
		print "<tr valign=top class=listsubtotal>";
		for (@column_index) { print "\n$column_data{$_}" }
		print "</tr>";

		$debit_subtotal = 0;
		$credit_subtotal = 0;
		$balance_subtotal = 0;
	   }
	}

	$column_data{no}   			= rpt_txt($no);
   	$column_data{"$form->{vc}number"}	= rpt_txt($ref->{"$form->{vc}number"});
   	$column_data{name} 			= rpt_txt($ref->{name});
   	$column_data{transdate} 		= rpt_txt($ref->{transdate});
   	$column_data{invnumber} 		= rpt_txt($ref->{invnumber});
   	$column_data{description} 		= rpt_txt($ref->{description});
   	$column_data{debit}  	  		= rpt_dec($ref->{debit});
   	$column_data{credit}    		= rpt_dec($ref->{credit});
   	$column_data{balance} 			= rpt_txt('&nbsp;');

	$debit_subtotal += $ref->{debit};
	$credit_subtotal += $ref->{credit};
	$balance_subtotal += $ref->{debit} - $ref->{credit};

	$debit_total += $ref->{debit};
	$credit_total += $ref->{credit};
	$balance_total += $ref->{debit} - $ref->{credit};

   	$column_data{balance}    		= rpt_dec($balance_subtotal);

	print "<tr valign=top class=listrow$i>";
	for (@column_index) { print "\n$column_data{$_}" }
	print "</tr>";
	$i++; $i %= 2; $no++;
   }

   # prepare data for footer
   $column_data{no}   			= rpt_txt('&nbsp;');
   $column_data{"$form->{vc}number"}  	= rpt_txt('&nbsp;');
   $column_data{name}    		= rpt_txt('&nbsp;');
   $column_data{transdate}  		= rpt_txt('&nbsp;');
   $column_data{invnumber} 		= rpt_txt('&nbsp;');
   $column_data{description} 		= rpt_txt('&nbsp;');
   $column_data{debit} 			= rpt_dec($debit_subtotal);
   $column_data{credit} 		= rpt_dec($credit_subtotal);
   $column_data{balance} 		= rpt_dec('&nbsp;');

   if ($form->{l_subtotal}){
	# print last subtotal
	print "<tr valign=top class=listsubtotal>";
	for (@column_index) { print "\n$column_data{$_}" }
	print "</tr>";
   }

   # grand total
   $column_data{debit} 			= rpt_dec($debit_total);
   $column_data{credit} 		= rpt_dec($credit_total);

   # print footer
   print "<tr valign=top class=listtotal>";
   for (@column_index) { print "\n$column_data{$_}" }
   print "</tr>";

   print qq|</table>|;
   $sth->finish;
   $dbh->disconnect;
}




#===================================
#
# Inventory Onhand by Warehouse
#
#==================================
#-------------------------------
sub onhand_search {
   $form->{title} = $locale->text('Inventory Onhand');
   &print_title;

   &start_form;
   &start_table;

   &bld_department;
   &bld_warehouse;
   &bld_partsgroup;

   &print_date('dateto', $locale->text('To'));
   &print_text('partnumber', $locale->text('Number'), 30);
   &print_select('partsgroup', $locale->text('Group'));
   &print_select('department', $locale->text('Department'));
   &print_select('warehouse', $locale->text('Warehouse'));
 
   print qq|<tr><th align=right>| . $locale->text('Include in Report') . qq|</th><td>|;

   &print_radio;
   &print_checkbox('l_no', $locale->text('No.'), '', '');
   &print_checkbox('l_warehouse', $locale->text('Warehouse'), 'checked', '');
   &print_checkbox('l_partnumber', $locale->text('Number'), 'checked', '');
   &print_checkbox('l_description', $locale->text('Description'), 'checked', '');
   &print_checkbox('l_partsgroup', $locale->text('Group'), 'checked', '');
   &print_checkbox('l_unit', $locale->text('Unit'), 'checked', '');
   &print_checkbox('l_onhand', $locale->text('Onhand'), 'checked', '<br>');
   &print_checkbox('l_subtotal', $locale->text('Subtotal'), '', '');
   &print_checkbox('l_csv', $locale->text('CSV'), '', '');
   #&print_checkbox('l_sql', $locale->text('SQL'), '');
   print qq|</td></tr>|;
   &end_table;
   print('<hr size=3 noshade>');
   $form->{nextsub} = 'onhand_list';
   &print_hidden('nextsub');
   &add_button($locale->text('Continue'));
   &end_form;
}

#-------------------------------
sub onhand_list {
  # callback to report list
   my $callback = qq|$form->{script}?action=onhand_list|;
   for (qw(path login sessionid)) { $callback .= "&$_=$form->{$_}" }

   &split_combos('department,warehouse,partsgroup');
   $form->{department_id} *= 1;
   $form->{warehouse_id} *= 1;
   $form->{partsgroup_id} *= 1;
   $partnumber = $form->like(lc $form->{partnumber});
   $description = $form->like(lc $form->{description});
   
   my $where = qq| (1 = 1)|;
   $where .= qq| AND (LOWER(p.partnumber) LIKE '$partnumber')| if $form->{partnumber};
   $where .= qq| AND (LOWER(p.description) LIKE '$name')| if $form->{description};
   $where .= qq| AND (p.partsgroup_id = $form->{partsgroup_id})| if $form->{partsgroup};
   $where .= qq| AND (i.department_id = $form->{department_id})| if $form->{department};
   $where .= qq| AND (i.warehouse_id = $form->{warehouse_id})| if $form->{warehouse};
   $where .= qq| AND (i.shippingdate <= '$form->{dateto}')| if $form->{dateto};

   @columns = qw(id warehouse partnumber description partsgroup unit onhand);
   if ($form->{summary}){
      @columns = qw(id partnumber description partsgroup unit onhand);
   }
   # if this is first time we are running this report.
   $form->{sort} = 'partnumber' if !$form->{sort};
   $form->{oldsort} = 'none' if !$form->{oldsort};
   $form->{direction} = 'ASC' if !$form->{direction};
   @columns = $form->sort_columns(@columns);

   my %ordinal = (	id => 1,
			warehouse => 2,
			partnumber => 3,
			description => 4,
			partsgroup => 5,
			unit => 6,
			onhand => 7
   );
   my $sort_order = $form->sort_order(\@columns, \%ordinal);

   # No. columns should always come first
   splice @columns, 0, 0, 'no';

   # Select columns selected for report display
   foreach $item (@columns) {
     if ($form->{"l_$item"} eq "Y") {
       push @column_index, $item;

       # add column to href and callback
       $callback .= "&l_$item=Y";
     }
   }
   for (qw(summary l_subtotal department warehouse partsgroup partnumber description dateto)){
      $callback .= "&$_=".$form->escape($form->{$_});
   }
   my $href = $callback;
   $form->{callback} = $form->escape($callback,1);

   if ($form->{summary}){
   	$query = qq|SELECT 
			p.id, 
			p.partnumber, 
			p.description, 
			pg.partsgroup,
			p.unit, 
			SUM(i.qty) AS onhand
			FROM inventory i
			JOIN parts p ON (p.id = i.parts_id)
			LEFT JOIN partsgroup pg ON (pg.id = p.partsgroup_id)
			WHERE $where
			GROUP BY 1, 2, 3, 4, 5
			ORDER BY $form->{sort} $form->{direction}|;
   } else {
   	$query = qq|SELECT 
			p.id, 
			w.description AS warehouse,
			p.partnumber, 
			p.description, 
			pg.partsgroup,
			p.unit, 
			SUM(i.qty) AS onhand
			FROM inventory i
			JOIN parts p ON (p.id = i.parts_id)
			LEFT JOIN warehouse w ON (w.id = i.warehouse_id)
			LEFT JOIN partsgroup pg ON (pg.id = p.partsgroup_id)
			WHERE $where
			GROUP BY 1, 2, 3, 4, 5, 6
			ORDER BY $form->{sort} $form->{direction}|;

   }
   # store oldsort/direction information
   $href .= "&direction=$form->{direction}&oldsort=$form->{sort}";

   $column_header{no}   		= rpt_hdr('no', $locale->text('No.'));
   $column_header{warehouse} 		= rpt_hdr('warehouse', $locale->text('Warehouse'), $href);
   $column_header{partnumber} 		= rpt_hdr('partnumber', $locale->text('Number'), $href);
   $column_header{description} 		= rpt_hdr('description', $locale->text('Description'), $href);
   $column_header{partsgroup}  		= rpt_hdr('partsgroup', $locale->text('Group'), $href);
   $column_header{unit}  		= rpt_hdr('unit', $locale->text('Unit'), $href);
   $column_header{onhand}  		= rpt_hdr('onhand', $locale->text('Onhand'), $href);

   $form->error($query) if $form->{l_sql};
   $dbh = $form->dbconnect(\%myconfig);
   my %defaults = $form->get_defaults($dbh, \@{['precision', 'company']});
   for (keys %defaults) { $form->{$_} = $defaults{$_} }

   if ($form->{l_csv} eq 'Y'){
	&export_to_csv($dbh, $query, 'parts_onhand');
	exit;
   }
   $sth = $dbh->prepare($query);
   $sth->execute || $form->dberror($query);

   $form->{title} = $locale->text('Inventory Onhand');
   &print_title;
   &print_criteria('partnumber',$locale->text('Number'));
   &print_criteria('warehouse_name', $locale->text('Warehouse'));
   &print_criteria('department_name', $locale->text('Department'));
   &print_criteria('dateto', $locale->text('To'));

   print qq|<table width=100%><tr class=listheading>|;
   # print header
   for (@column_index) { print "\n$column_header{$_}" }
   print qq|</tr>|; 

   # Subtotal and total variables
   my $qty_subtotal = 0;
   my $qty_total = 0;
   my $amount_subtotal = 0;
   my $amount_total = 0;

   # print data
   my $i = 1; my $no = 1;
   my $groupbreak = 'none';
   while (my $ref = $sth->fetchrow_hashref(NAME_lc)){
   	$form->{link} = qq|ic.pl?action=edit&id=$ref->{id}&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}&callback=$form->{callback}|;
	$groupbreak = $ref->{$form->{sort}} if $groupbreak eq 'none';
	if ($form->{l_subtotal}){
	   if ($groupbreak ne $ref->{$form->{sort}}){
		$groupbreak = $ref->{$form->{sort}};
		# prepare data for footer

   		$column_data{no}   		= rpt_txt('&nbsp;');
   		$column_data{warehouse}  	= rpt_txt('&nbsp;');
   		$column_data{partnumber}  	= rpt_txt('&nbsp;');
   		$column_data{description} 	= rpt_txt('&nbsp;');
   		$column_data{partsgroup} 	= rpt_txt('&nbsp;');
   		$column_data{unit} 		= rpt_txt('&nbsp;');
   		$column_data{onhand} 		= rpt_dec($qty_subtotal);

		# print footer
		print "<tr valign=top class=listsubtotal>";
		for (@column_index) { print "\n$column_data{$_}" }
		print "</tr>";

		$qty_subtotal = 0;
		$amount_subtotal = 0;
	   }
	}

	$column_data{no}   		= rpt_txt($no);
   	$column_data{warehouse}		= rpt_txt($ref->{warehouse});
   	$column_data{partnumber}	= rpt_txt($ref->{partnumber});
   	$column_data{description} 	= rpt_txt($ref->{description});
   	$column_data{partsgroup}    	= rpt_txt($ref->{partsgroup});
   	$column_data{unit}    		= rpt_txt($ref->{unit});
   	$column_data{onhand}    	= rpt_dec($ref->{onhand});

	print "<tr valign=top class=listrow$i>";
	for (@column_index) { print "\n$column_data{$_}" }
	print "</tr>";
	$i++; $i %= 2; $no++;

	$qty_subtotal += $ref->{onhand};
	$qty_total += $ref->{onhand};

	$amount_subtotal += $ref->{amount};
	$amount_total += $ref->{amount};
   }

   # prepare data for footer
   $column_data{no}   		= rpt_txt('&nbsp;');
   $column_data{warehouse}  	= rpt_txt('&nbsp;');
   $column_data{partnumber}  	= rpt_txt('&nbsp;');
   $column_data{description} 	= rpt_txt('&nbsp;');
   $column_data{partsgroup} 	= rpt_txt('&nbsp;');
   $column_data{unit} 		= rpt_txt('&nbsp;');
   $column_data{onhand} 	= rpt_dec($qty_subtotal);


   if ($form->{l_subtotal}){
	# print last subtotal
	print "<tr valign=top class=listsubtotal>";
	for (@column_index) { print "\n$column_data{$_}" }
	print "</tr>";
   }

   # grand total
   $column_data{onhand} = rpt_dec($qty_total);
   $column_data{amount} = rpt_dec($amount_total);

   # print footer
   print "<tr valign=top class=listtotal>";
   for (@column_index) { print "\n$column_data{$_}" }
   print "</tr>";

   print qq|</table>|;
   $sth->finish;
   $dbh->disconnect;
}

#===================================
#
# Inventory Activity
#
#==================================
#-------------------------------
sub iactivity_search {

   $form->{title} = $locale->text('Inventory Activity'); 
   &print_title;
   
   &start_form;
   &start_table;

   &bld_department('selectdepartment', 1);
   &bld_warehouse;
   &bld_partsgroup;

   &print_text('partnumber', $locale->text('Number'), 30);
   &print_date('datefrom', $locale->text('From'));
   &print_date('dateto', $locale->text('To'));
   &print_select('partsgroup', $locale->text('Group'));
   &print_select('department', $locale->text('Department'));
   &print_select('warehouse', $locale->text('Warehouse'));
  
   print qq|<tr><th align=right>| . $locale->text('Include in Report') . qq|</th><td>|;

   &print_checkbox('l_no', $locale->text('No.'), '', '<br>');
   &print_checkbox('l_shippingdate', $locale->text('Date'), 'checked', '');
   &print_checkbox('l_reference', $locale->text('Reference'), 'checked', '');
   &print_checkbox('l_department', $locale->text('Department'), '', '');
   &print_checkbox('l_warehouse', $locale->text('Warehouse'), 'checked', '');
   &print_checkbox('l_warehouse2', $locale->text('Warehouse2'), 'checked', '<br>');
   &print_checkbox('l_partnumber', $locale->text('Number'), 'checked', '');
   &print_checkbox('l_description', $locale->text('Description'), '', '');
   &print_checkbox('l_unit', $locale->text('Unit'), 'checked', '');
   &print_checkbox('l_in', $locale->text('In'), 'checked', '');
   &print_checkbox('l_out', $locale->text('Out'), 'checked', '');
   &print_checkbox('l_onhand', $locale->text('Onhand'), 'checked', '');
   &print_checkbox('l_cost', $locale->text('Cost'), 'checked', '');
   &print_checkbox('l_cogs', $locale->text('Total Cost'), 'checked', '');
   &print_checkbox('l_cogs_balance', $locale->text('Cost Balance'), 'checked', '<br>');
   &print_checkbox('l_subtotal', $locale->text('Subtotal'), 'checked', '');
   &print_checkbox('l_csv', $locale->text('CSV'), '', '');
   #&print_checkbox('l_sql', $locale->text('SQL'), '', '<br>');

   print qq|</td></tr>|;
   &end_table;
   print('<hr size=3 noshade>');
   $form->{nextsub} = 'iactivity_list';
   &print_hidden('nextsub');
   &add_button($locale->text('Continue'));
   &end_form;
}

#-------------------------------
sub iactivity_list {
   # callback to report list
   my $callback = qq|$form->{script}?action=iactivity_list|;
   for (qw(path login sessionid)) { $callback .= "&$_=$form->{$_}" }

   &split_combos('department,warehouse,partsgroup');
   $form->{department_id} *= 1;
   $form->{warehouse_id} *= 1;
   $form->{partsgroup_id} *= 1;
   $partnumber = $form->like(lc $form->{partnumber});
   $description = $form->like(lc $form->{description});
   
   my $where = qq| (1 = 1)|;
   my $openingwhere;

   if ($form->{partnumber}){
   	$where .= qq| AND (LOWER(p.partnumber) LIKE '$partnumber')|;
	$callback .= "&partnumber=".$form->escape($form->{partnumber});
   }
   if ($form->{description}){
   	$where .= qq| AND (LOWER(i.description) LIKE '$name')|;
	$callback .= "&description=".$form->escape($form->{description});
   }
   if ($form->{partsgroup}){
   	$where .= qq| AND (p.partsgroup_id = $form->{partsgroup_id})|;
	$callback .= "&partsgroup=".$form->escape($form->{partsgroup});
   }
   if ($form->{datefrom}){
   	$where .= qq| AND (i.shippingdate >= '$form->{datefrom}')|;
	$callback .= "&datefrom=$form->{datefrom}";
   	$openingwhere .= qq| AND (shippingdate < '$form->{datefrom}')|;
   }
   if ($form->{dateto}){
   	$where .= qq| AND (i.shippingdate <= '$form->{dateto}')|;
	$callback .= "&dateto=$form->{dateto}";
   }

   if ($form->{department}){
      $where .= qq| AND (i.department_id = $form->{department_id})|;
      $openingwhere .= qq| AND (department_id = $form->{department_id})|;
      $form->{l_department} = '';
      $callback .= "&department=".$form->escape($form->{department});
   }
   if ($form->{warehouse}){
      $where .= qq| AND (i.warehouse_id = $form->{warehouse_id})|;
      $openingwhere .= qq| AND (warehouse_id = $form->{warehouse_id})|;
      $form->{l_warehouse} = '';
      $callback .= "&warehouse=".$form->escape($form->{warehouse});
   }

   @columns = qw(partnumber description id shippingdate reference department warehouse warehouse2 in out onhand cost cogs cogs_balance);
   # if this is first time we are running this report.
   $form->{sort} = 'partnumber' if !$form->{sort};
   $form->{oldsort} = 'none' if !$form->{oldsort};
   $form->{direction} = 'ASC' if !$form->{direction};
   @columns = $form->sort_columns(@columns);

   my %ordinal = (
			partnumber => 1,
			description => 2,
			shippingdate => 3,
			reference => 4,
			department => 5,
			warehouse => 6,
			warehouse2 => 7,
			in => 8,
			out => 9,
			onhand => 10,
			cost => 11,
			cogs => 12,
			cogs_balance => 13
   );
   my $sort_order = $form->sort_order(\@columns, \%ordinal);

   # No. columns should always come first
   splice @columns, 0, 0, 'no';

   # Select columns selected for report display
   foreach $item (@columns) {
     if ($form->{"l_$item"} eq "Y") {
       push @column_index, $item;

       # add column to href and callback
       $callback .= "&l_$item=Y";
     }
   }
   for (qw(l_subtotal partnumber datefrom dateto partsgroup department warehouse)){
      $callback .= "&$_=".$form->escape($form->{$_});
   }
   my $href = $callback;
   $form->{callback} = $form->escape($callback,1);

   $query = qq/SELECT
		i.parts_id,
		p.partnumber, 
		i.description, 
		i.trans_id, 
		i.shippingdate,
		i.qty,
		i.cogs,
		i.cost,
		d.description AS department,
		w.description AS warehouse, 
		w2.description AS warehouse2,
		trf.trfnumber AS reference,
		ap.invnumber AS ap_reference,
		ar.invnumber AS ar_reference
	      FROM inventory i
		JOIN parts p ON (p.id = i.parts_id)
		LEFT JOIN department d ON (i.department_id = d.id)
		LEFT JOIN warehouse w ON (i.warehouse_id = w.id)
		LEFT JOIN warehouse w2 ON (i.warehouse_id2 = w2.id)
		LEFT JOIN trf ON (i.trans_id = trf.id)
		LEFT JOIN ap ON (i.trans_id = ap.id)
		LEFT JOIN ar ON (i.trans_id = ar.id)
		WHERE $where
		ORDER BY p.partnumber, i.shippingdate/;
		#ORDER BY $form->{sort} $form->{direction}|;

   # store oldsort/direction information
   $href .= "&direction=$form->{direction}&oldsort=$form->{sort}";

   $column_header{no}   		= rpt_hdr('no', $locale->text('No.'));
   $column_header{shippingdate} 	= rpt_hdr('shippingdate', $locale->text('Date'), $href);
   $column_header{reference} 		= rpt_hdr('reference', $locale->text('Reference'), $href);
   $column_header{department} 		= rpt_hdr('department', $locale->text('Department'), $href);
   $column_header{warehouse} 		= rpt_hdr('warehouse', $locale->text('Warehouse'), $href);
   $column_header{warehouse2} 		= rpt_hdr('warehouse2', $locale->text('Warehouse2'), $href);
   $column_header{partnumber} 		= rpt_hdr('partnumber', $locale->text('Number'), $href);
   $column_header{description} 		= rpt_hdr('description', $locale->text('Description'), $href);
   $column_header{in}  			= rpt_hdr('in', $locale->text('In'), $href);
   $column_header{out}  		= rpt_hdr('out', $locale->text('Out'), $href);
   $column_header{onhand}  		= rpt_hdr('onhand', $locale->text('Onhand'), $href);
   $column_header{cost}  		= rpt_hdr('cost', $locale->text('Last Cost'), $href);
   $column_header{cogs}  		= rpt_hdr('cogs', $locale->text('Total Cost'), $href);
   $column_header{cogs_balance}  	= rpt_hdr('cogs_balance', $locale->text('Cost Balance'), $href);

   $form->error($query) if $form->{l_sql};
   $dbh = $form->dbconnect(\%myconfig);
   my %defaults = $form->get_defaults($dbh, \@{['precision', 'company']});
   for (keys %defaults) { $form->{$_} = $defaults{$_} }

   if ($form->{l_csv} eq 'Y'){
	&export_to_csv($dbh, $query, 'inventory_activity');
	exit;
   }
   $sth = $dbh->prepare($query);
   $sth->execute || $form->dberror($query);

   $form->{title} = $locale->text('Inventory Activity');
   &print_title;
   &print_criteria('partnumber',$locale->text('Number'));
   &print_criteria('warehouse_name', $locale->text('Warehouse'));
   &print_criteria('department_name', $locale->text('Department'));

   print qq|<table width=100%><tr class=listheading>|;
   # print header
   for (@column_index) { print "\n$column_header{$_}" }
   print qq|</tr>|; 

   # Subtotal and total variables
   my $in_subtotal = 0;
   my $in_total = 0;
   my $out_subtotal = 0;
   my $out_total = 0;
   my $onhand = 0;
   my $cogs_balance = 0;

   # print data
   my $i = 1; my $no = 1;
   my $groupbreak = 'none';
   while (my $ref = $sth->fetchrow_hashref(NAME_lc)){
   	$form->{link} = qq|$form->{script}?action=edit&id=$ref->{id}&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}&callback=$form->{callback}|;
	#$groupbreak = $ref->{$form->{sort}} if $groupbreak eq 'none';
	#$groupbreak = $ref->{partnumber} if $groupbreak eq 'none';
	if ($form->{l_subtotal}){
	   #if ($groupbreak ne $ref->{$form->{sort}}){
	   if ($groupbreak ne $ref->{partnumber}){
		#$groupbreak = $ref->{$form->{sort}};
		$groupbreak = $ref->{partnumber};

		# prepare data for footer
   		$column_data{no}   		= rpt_txt('&nbsp;');
   		$column_data{shippingdate} 	= rpt_txt('&nbsp;');
   		$column_data{reference} 	= rpt_txt('&nbsp;');
   		$column_data{department} 	= rpt_txt('&nbsp;');
   		$column_data{warehouse} 	= rpt_txt('&nbsp;');
   		$column_data{warehouse2} 	= rpt_txt('&nbsp;');
   		$column_data{partnumber}  	= rpt_txt('&nbsp;');
   		$column_data{description} 	= rpt_txt('&nbsp;');
   		$column_data{unit} 		= rpt_txt('&nbsp;');
   		$column_data{in} 		= rpt_dec($in_subtotal);
   		$column_data{out} 		= rpt_dec($out_subtotal);
   		$column_data{onhand} 		= rpt_txt('&nbsp;');
   		$column_data{cost} 		= rpt_txt('&nbsp;');
   		$column_data{cogs} 		= rpt_txt('&nbsp;');
   		$column_data{cogs_balance} 	= rpt_txt('&nbsp;');

	        $in_subtotal = 0;
		$out_subtotal = 0;
		$onhand = 0;
		$cogs_balance = 0;

		# print footer
		print "<tr valign=top class=listsubtotal>";
		for (@column_index) { print "\n$column_data{$_}" }
		print "</tr>";
		if ($form->{datefrom}){
   		   my $openingquery = qq|
			SELECT SUM(qty) 
			FROM inventory 
			WHERE parts_id = $ref->{parts_id}
			$openingwhere
		   |;
		   my $openingqty = $dbh->selectrow_array($openingquery);
		   if ($openingqty != 0){
		      $onhand = $openingqty;
   		      $column_data{in} 		= rpt_dec($in_subtotal);
   		      $column_data{out} 	= rpt_dec($out_subtotal);
   		      $column_data{onhand} 	= rpt_dec($onhand);

		      # print footer
		      print "<tr valign=top class=listrow0>";
		      for (@column_index) { print "\n$column_data{$_}" }
		      print "</tr>";
		   }
		}
	   }
	}
	$in  = ($ref->{qty} > 0) ? $ref->{qty} : 0;
	$out = ($ref->{qty} < 0) ? 0 - $ref->{qty} : 0;

	$in_subtotal += $in;
	$in_total += $in;
	$out_subtotal += $out;
	$out_total += $out;
        $onhand += ($in - $out);
	$cogs_balance += $ref->{cogs};

	$column_data{no}   		= rpt_txt($no);
   	$column_data{shippingdate}    	= rpt_txt($ref->{shippingdate});
   	$column_data{reference}    	= rpt_txt($ref->{reference} . $ref->{ap_reference} . $ref->{ar_reference});
   	$column_data{department}    	= rpt_txt($ref->{department});
   	$column_data{warehouse}    	= rpt_txt($ref->{warehouse});
   	$column_data{warehouse2}    	= rpt_txt($ref->{warehouse2});
   	$column_data{partnumber}	= rpt_txt($ref->{partnumber});
   	$column_data{description} 	= rpt_txt($ref->{description});
   	$column_data{unit}    		= rpt_txt($ref->{unit});
   	$column_data{in}    		= rpt_dec($in);
   	$column_data{out}    		= rpt_dec($out);
   	$column_data{onhand}    	= rpt_dec($onhand);
   	$column_data{cost}    		= rpt_dec($ref->{cost});
   	$column_data{cogs}    		= rpt_dec($ref->{cogs});
   	$column_data{cogs_balance}    	= rpt_dec($cogs_balance);

	print "<tr valign=top class=listrow$i>";
	for (@column_index) { print "\n$column_data{$_}" }
	print "</tr>";
	$i++; $i %= 2; $no++;
   }

   # prepare data for footer
   $column_data{no}   		= rpt_txt('&nbsp;');
   $column_data{shippingdate} 	= rpt_txt('&nbsp;');
   $column_data{reference} 	= rpt_txt('&nbsp;');
   $column_data{department} 	= rpt_txt('&nbsp;');
   $column_data{warehouse} 	= rpt_txt('&nbsp;');
   $column_data{warehouse2} 	= rpt_txt('&nbsp;');
   $column_data{partnumber}  	= rpt_txt('&nbsp;');
   $column_data{description} 	= rpt_txt('&nbsp;');
   $column_data{unit} 		= rpt_txt('&nbsp;');
   $column_data{in} 		= rpt_dec($in_subtotal);
   $column_data{out} 		= rpt_dec($out_subtotal);
   $column_data{onhand} 	= rpt_txt('&nbsp;');
   $column_data{cost} 		= rpt_txt('&nbsp;');
   $column_data{cogs} 		= rpt_txt('&nbsp;');
   $column_data{cogs_balance} 	= rpt_txt('&nbsp;');

   if ($form->{l_subtotal}){
	# print last subtotal
	print "<tr valign=top class=listsubtotal>";
	for (@column_index) { print "\n$column_data{$_}" }
	print "</tr>";
   }

   # grand total
   $column_data{in} = rpt_dec($in_total);
   $column_data{out} = rpt_dec($out_total);

   # print footer
   print "<tr valign=top class=listtotal>";
   for (@column_index) { print "\n$column_data{$_}" }
   print "</tr>";

   print qq|</table>|;
   $sth->finish;
   $dbh->disconnect;
}

#===================================
#
# AR/AP Transactions Report
#
#===================================
#-----------------------------------
# $locale->text('AP Transactions');
# $locale->text('AR Transactions');
sub trans_search {
   $form->{title} = $locale->text("$form->{aa} Transactions");
   &print_title;

   &bld_department;
   &bld_warehouse;
   &bld_partsgroup;
   &bld_employee;

   &start_form;
   &start_table;

   my $table = lc $form->{aa};
   my $db = ($table eq 'ar') ? 'customer' : 'vendor';
   #$locale->text('Salesperson');
   #$locale->text('Employee');
   my $employee_caption = ($table eq 'ar') ? 'Salesperson' : 'Employee';

   #$locale->text('Customer Number');
   #$locale->text('Vendor Number');
   &print_text("${db}number", $locale->text((ucfirst $db) . ' Number'), 15);
   &print_text('name', $locale->text('Name'), 30);
   &print_text('invnumber', $locale->text('Invoice Number'), 15);
   &print_text('description', $locale->text('Description'), 30);
   &print_text('notes', $locale->text('Notes'), 30);
   &print_date('fromdate', $locale->text('From'));
   &print_date('todate', $locale->text('To'));

   &print_select('department', $locale->text('Department'));
   &print_select('warehouse', $locale->text('Warehouse'));
   &print_select('employee', $locale->text($employee_caption));

   &print_text('partnumber', $locale->text('Number'), 15);
   &print_select('partsgroup', $locale->text('Group'));

   print qq|<tr><th align=right>| . $locale->text('Include in Report') . qq|</th><td>|;
   &print_radio;
   &print_checkbox('invoices', $locale->text('Invoices'), 'checked','');
   &print_checkbox('trans', $locale->text('Transactions'), 'checked', '<br>');
   &print_checkbox('l_no', $locale->text('No.'), '', '');
   &print_checkbox("l_${db}number", $locale->text('Number'), 'checked', '');
   &print_checkbox('l_name', $locale->text('Name'), 'checked', '');
   &print_checkbox('l_invnumber', $locale->text('Invoice Number'), 'checked', '');
   &print_checkbox('l_transdate', $locale->text('Invoice Date'), 'checked', '<br>');
   &print_checkbox('l_partnumber', $locale->text('Number'), 'checked', '');
   &print_checkbox('l_description', $locale->text('Description'), 'checked', '');
   &print_checkbox('l_qty', $locale->text('Qty'), 'checked', '');
   &print_checkbox('l_sellprice', $locale->text('Sell Price'), 'checked', '<br>');
   &print_checkbox('l_amount', $locale->text('Amount'), 'checked', '');
   &print_checkbox('l_tax', $locale->text('Tax'), '', '');
   &print_checkbox('l_total', $locale->text('Total'), '', '');
   if ($form->{aa} eq 'AR'){
      &print_checkbox('l_cogs', $locale->text('COGS'), 'checked', '');
      &print_checkbox('l_markup', $locale->text('Markup %'), 'checked', '');
   }

   &print_checkbox('l_employee', $locale->text($salesperson_caption), 'checked', '<br>');
   &print_checkbox('l_subtotal', $locale->text('Subtotal'), '', '');
   &print_checkbox('l_subtotalonly', $locale->text('Subtotal Only'), '', '');
   &print_checkbox('l_csv', $locale->text('CSV'), '', '<br>');
   &print_checkbox('l_sql', $locale->text('SQL'), '');

   print qq|</td></tr>|;
   &end_table;
   print('<hr size=3 noshade>');
   $form->{nextsub} = 'trans_list';
   &print_hidden('nextsub');
   &print_hidden('aa');
   &print_hidden('db');
   &add_button($locale->text('Continue'));
   &end_form;
}

#-------------------------------
sub trans_list {
   # callback to report list
   my $callback = qq|$form->{script}?action=trans_list|;
   for (qw(path login)) { $callback .= "&$_=$form->{$_}" }

   &split_combos('department,warehouse,partsgroup,employee');
   $form->{department_id} *= 1;
   $form->{warehouse_id} *= 1;
   $form->{partsgroup_id} *= 1;
   $form->{employee_id} *= 1;

   my $table = lc $form->{aa};
   my $db = ($table eq 'ar') ? 'customer' : 'vendor';
   my $employee_caption = ($table eq 'ar') ? 'Salesperson' : 'Employee';
   my $sign = ($table eq 'ar') ? 1 : -1;

   $vcnumber = $form->like(lc $form->{"${db}number"});
   $name = $form->like(lc $form->{name});
   $invnumber = $form->like(lc $form->{invnumber});
   $description = $form->like(lc $form->{description});
   $notes = $form->like(lc $form->{notes});
   $partnumber = $form->like(lc $form->{partnumber});
   
   my $where = qq| (1 = 1)|;
   $where .= qq| AND (aa.transdate >= '$form->{fromdate}')| if $form->{fromdate};
   $where .= qq| AND (aa.transdate <= '$form->{todate}')| if $form->{todate};
   $where .= qq| AND (aa.department_id = $form->{department_id})| if $form->{department};
   $where .= qq| AND (aa.warehouse_id = $form->{warehouse_id})| if $form->{warehouse};
   $where .= qq| AND (aa.employee_id = $form->{employee_id})| if $form->{employee};
   $where .= qq| AND (LOWER(ct.${db}number) LIKE '$vcnumber')| if $form->{"${db}number"};
   $where .= qq| AND (LOWER(ct.name) LIKE '$name')| if $form->{name};
   $where .= qq| AND (LOWER(aa.invnumber) LIKE '$invnumber')| if $form->{invnumber};
   $where .= qq| AND (LOWER(aa.description) LIKE '$description')| if $form->{description};
   $where .= qq| AND (LOWER(aa.notes) LIKE '$notes')| if $form->{notes};

   my $fifowhere;
   if ($form->{warehouse}){
	$fifowhere = qq| AND f.warehouse_id = $form->{warehouse_id}|;
   } else {
	$fifowhere = qq| AND f.warehouse_id = 0|;
   }

   if (!$form->{summary}){
     $where .= qq| AND (p.partsgroup_id = $form->{partsgroup_id})| if $form->{partsgroup};
     $where .= qq| AND (LOWER(p.partnumber) LIKE '$partnumber')| if $form->{partnumber};
   }
   if ($form->{invoices} || $form->{trans}){
      if ($form->{invoices}){
         $where .= qq| AND aa.invoice| unless $form->{trans};
      }
      if ($form->{trans}){
	 $where .= qq| AND NOT aa.invoice | unless $form->{invoices};
      }
   }
   @columns = (qw(id invnumber transdate customernumber vendornumber name partnumber description qty sellprice amount tax total cogs markup employee));

   # if this is first time we are running this report.
   $form->{sort} = "invnumber" if !$form->{sort};
   $form->{oldsort} = 'none' if !$form->{oldsort};
   $form->{direction} = 'ASC' if !$form->{direction};
   @columns = $form->sort_columns(@columns);

   my %ordinal = (	id => 1,
			invnumber => 2,
			transdate => 3,
			customernumber => 4,
			vendornumber => 4,
			name => 5,
			partnumber => 6,
			description => 7,
			qty => 8,
			sellprice => 9,
			amount => 10,
			tax => 11,
			total => 12,
			cogs => 13,
			markup => 14
   );
   my $sort_order = $form->sort_order(\@columns, \%ordinal);

   # No. columns should always come first
   splice @columns, 0, 0, 'no';

   # Remove columns based on report type
   if ($form->{summary}){
      for (qw(partnumber description qty sellprice)) { $form->{"l_$_"} = ""}
   } else {
      for (qw(total)) { $form->{"l_$_"} = ""}
   }

   # Select columns selected for report display
   foreach $item (@columns) {
     if ($form->{"l_$item"} eq "Y") {
       push @column_index, $item;

       # add column to href and callback
       $callback .= "&l_$item=Y";
     }
   }
   for (qw(aa l_subtotal l_subtotalonly summary)){ $callback .= "&$_=$form->{$_}" }
   for (qw(customernumber vendornumber name invnumber description notes fromdate todate partnumber department warehouse partsgroup employee)){ $callback .= "&$_=".$form->escape($form->{$_},1) }

   my $href = $callback;
   $form->{callback} = $form->escape($callback,1);

   if ($form->{summary}){
   	$query = qq|
		SELECT 
		  aa.id, 
		  aa.invnumber,
		  aa.transdate,
		  ct.${db}number, 
		  ct.name, 
		  e.name AS employee,
		  aa.netamount AS amount,
		  aa.amount - aa.netamount AS tax,
		  aa.amount AS total,

	(SELECT SUM(0-ac.amount) 
	FROM acc_trans ac 
	JOIN chart c ON (c.id = ac.chart_id) 
	WHERE ac.trans_id = aa.id 
	AND c.link LIKE '%IC_cogs%') AS cogs,

		aa.invoice,
		aa.till

		FROM $table aa
		JOIN $db ct ON (ct.id = aa.${db}_id)
		LEFT JOIN employee e ON (e.id = aa.employee_id)

		WHERE $where
		ORDER BY $form->{sort} $form->{direction}|;
   } else {
   	$query = qq|
		SELECT 
		  aa.id, 
		  aa.invnumber,
		  aa.transdate,
		  ct.${db}number, 
		  ct.name, 
		  e.name AS employee,
		  p.partnumber,
		  p.description,
		  i.qty * $sign AS qty,
		  i.sellprice,
		  i.qty * i.sellprice * $sign AS amount,

	(SELECT SUM(taxamount)
	FROM invoicetax it
	WHERE it.invoice_id = i.id) AS tax,

		  0 AS total,

	(SELECT SUM(qty * costprice)
	FROM fifo f
	WHERE f.trans_id = aa.id
	AND f.parts_id = i.parts_id 
	$fifowhere) AS cogs,

		aa.invoice,
		aa.till

		FROM $table aa
		JOIN invoice i ON (i.trans_id = aa.id)
		JOIN parts p ON (p.id = i.parts_id)
		JOIN $db ct ON (ct.id = aa.${db}_id)
		LEFT JOIN employee e ON (e.id = aa.employee_id)

		WHERE $where
		ORDER BY $form->{sort} $form->{direction}|;
   }

   # store oldsort/direction information
   $href .= "&direction=$form->{direction}&oldsort=$form->{sort}";

   $column_header{no}   		= rpt_hdr('no', $locale->text('No.'));
   $column_header{invnumber}    	= rpt_hdr('invnumber', $locale->text('Invoice Number'), $href);
   $column_header{transdate}    	= rpt_hdr('transdate', $locale->text('Invoice Date'), $href);
   $column_header{"${db}number"} 	= rpt_hdr("${db}number", $locale->text('Number'), $href);
   $column_header{name}    		= rpt_hdr('name', $locale->text('Name'), $href);
   $column_header{partnumber}    	= rpt_hdr('partnumber', $locale->text('Number'), $href);
   $column_header{description}  	= rpt_hdr('description', $locale->text('Description'), $href);
   $column_header{qty}  		= rpt_hdr('qty', $locale->text('Qty'), $href);
   $column_header{sellprice}  		= rpt_hdr('sellprice', $locale->text('Price'), $href);
   $column_header{amount}  		= rpt_hdr('amount', $locale->text('Amount'), $href);
   $column_header{tax}  		= rpt_hdr('tax', $locale->text('Tax'), $href);
   $column_header{total}  		= rpt_hdr('total', $locale->text('Total'), $href);
   $column_header{cogs}  		= rpt_hdr('cogs', $locale->text('COGS'), $href);
   $column_header{markup}  		= rpt_hdr('markup', $locale->text('%'));
   $column_header{employee}  		= rpt_hdr('employee', $locale->text($employee_caption), $href);

   $form->error($query) if $form->{l_sql};
   $dbh = $form->dbconnect(\%myconfig);
   my %defaults = $form->get_defaults($dbh, \@{['precision', 'company']});
   for (keys %defaults) { $form->{$_} = $defaults{$_} }

   if ($form->{l_csv} eq 'Y'){
	&export_to_csv($dbh, $query, "${table}_transactions");
	exit;
   }
   $sth = $dbh->prepare($query);
   $sth->execute || $form->dberror($query);

   $form->{title} = $locale->text("$form->{aa} Transactions");
   &print_title;

   # Print report criteria
   &print_criteria("${db}number", $locale->text('Number'));
   &print_criteria('name', $locale->text('Name'));
   &print_criteria('invnumber', $locale->text('Invoice Number'));
   &print_criteria('description', $locale->text('Description'));
   &print_criteria('notes', $locale->text('Notes'));
   &print_criteria('fromdate', $locale->text('From'));
   &print_criteria('todate', $locale->text('To'));
   &print_criteria('department_name', $locale->text('Department'));
   &print_criteria('warehouse_name', $locale->text('Warehouse'));
   &print_criteria('employee_name', $employee_caption);
   &print_criteria('partnumber',$locale->text( 'Number'));
   &print_criteria('partsgroup_name', $locale->text('Group'));

   print qq|<table width=100%><tr class=listheading>|;
   # print header
   for (@column_index) { print "\n$column_header{$_}" }
   print qq|</tr>|; 

   # Subtotal and total variables
   my $qty_subtotal = 0;
   my $amount_subtotal = 0;
   my $tax_subtotal = 0;
   my $total_subtotal = 0;
   my $cogs_subtotal = 0;

   my $qty_total = 0;
   my $amount_total = 0;
   my $tax_total = 0;
   my $total_total = 0;
   my $cogs_total = 0;

   # print data
   my $i = 1; my $no = 1;
   my $groupbreak = 'none';
   my $oldgroupbreak;
   while (my $ref = $sth->fetchrow_hashref(NAME_lc)){
        $module = ($ref->{invoice}) ? ($form->{aa} eq 'AR') ? "is.pl" : "ir.pl" : "$table.pl";
        $module = ($ref->{till}) ? "ps.pl" : $module;
   	$form->{link} = qq|$module?action=edit&id=$ref->{id}&path=$form->{path}&login=$form->{login}&callback=$form->{callback}|;
	$groupbreak = $ref->{$form->{sort}} if $groupbreak eq 'none';
	if ($form->{l_subtotal}){
	   if ($groupbreak ne $ref->{$form->{sort}}){
		$oldgroupbreak = $groupbreak;
		$groupbreak = $ref->{$form->{sort}};
		# prepare data for footer

   		$column_data{no}   			= rpt_txt('&nbsp;');
   		$column_data{invnumber}   		= rpt_txt('&nbsp;');
   		$column_data{transdate}   		= rpt_txt('&nbsp;');
   		$column_data{"${db}number"}  		= rpt_txt('&nbsp;');
   		$column_data{name}    			= rpt_txt('&nbsp;');
   		$column_data{partnumber}    		= rpt_txt('&nbsp;');
   		$column_data{description}    		= rpt_txt('&nbsp;');
   		$column_data{qty} 			= rpt_dec($qty_subtotal);
   		$column_data{sellprice} 		= rpt_txt('&nbsp;');
   		$column_data{amount} 			= rpt_dec($amount_subtotal);
   		$column_data{tax} 			= rpt_dec($tax_subtotal);
   		$column_data{total} 			= rpt_dec($total_subtotal);
   		$column_data{cogs} 			= rpt_dec($cogs_subtotal);
   		$column_data{employee}   		= rpt_txt('&nbsp;');
		# Print subtotal value of sorted column as heading
		$column_data{$form->{sort}}		= rpt_txt($oldgroupbreak) if $form->{l_subtotalonly};
		my $markup = 0;
		if ($amount_subtotal > 0){
		   $markup = (($amount_subtotal - $cogs_subtotal) * 100)/$amount_subtotal;
		}
   		$column_data{markup} 			= rpt_dec($markup);

		# print footer
		print "<tr valign=top class=listsubtotal>";
		for (@column_index) { print "\n$column_data{$_}" }
		print "</tr>";

   		$qty_subtotal = 0;
   		$amount_subtotal = 0;
   		$tax_subtotal = 0;
   		$total_subtotal = 0;
   		$cogs_subtotal = 0;
	   }
	}

	$column_data{no}   			= rpt_txt($no);
   	$column_data{invnumber} 		= rpt_txt($ref->{invnumber}, $form->{link});
   	$column_data{transdate} 		= rpt_txt($ref->{transdate});
   	$column_data{"${db}number"}		= rpt_txt($ref->{"${db}number"});
   	$column_data{name} 			= rpt_txt($ref->{name});
   	$column_data{partnumber} 		= rpt_txt($ref->{partnumber});
   	$column_data{description} 		= rpt_txt($ref->{description});
   	$column_data{qty}    			= rpt_dec($ref->{qty});
   	$column_data{sellprice}    		= rpt_dec($ref->{sellprice});
   	$column_data{amount}    		= rpt_dec($ref->{amount});
   	$column_data{tax}    			= rpt_dec($ref->{tax});
   	$column_data{total}    			= rpt_dec($ref->{total});
   	$column_data{cogs}    			= rpt_dec($ref->{cogs});
	if ($ref->{amount} > 0){
   	  $column_data{markup}    		= rpt_dec((($ref->{amount} - $ref->{cogs})* 100)/$ref->{amount});
	} else {
   	  $column_data{markup}    		= rpt_dec(0);
	}
   	$column_data{employee} 			= rpt_txt($ref->{employee});

	if (!$form->{l_subtotalonly}){
	   print "<tr valign=top class=listrow$i>";
	   for (@column_index) { print "\n$column_data{$_}" };
	   print "</tr>";
	}
	$i++; $i %= 2; $no++;

   	$qty_subtotal += $ref->{qty};
   	$amount_subtotal += $ref->{amount};
   	$tax_subtotal += $ref->{tax};
   	$total_subtotal += $ref->{total};
   	$cogs_subtotal += $ref->{cogs};

   	$qty_total += $ref->{qty};
   	$amount_total += $ref->{amount};
   	$tax_total += $ref->{tax};
   	$total_total += $ref->{total};
   	$cogs_total += $ref->{cogs};
   }

   # prepare data for footer
   $column_data{no}   			= rpt_txt('&nbsp;');
   $column_data{invnumber}   		= rpt_txt('&nbsp;');
   $column_data{transdate}   		= rpt_txt('&nbsp;');
   $column_data{"${db}number"}  	= rpt_txt('&nbsp;');
   $column_data{name}    		= rpt_txt('&nbsp;');
   $column_data{partnumber}    		= rpt_txt('&nbsp;');
   $column_data{description}   		= rpt_txt('&nbsp;');

   $column_data{qty} 			= rpt_dec($qty_subtotal);
   $column_data{sellprice} 		= rpt_txt('&nbsp;');
   $column_data{amount} 		= rpt_dec($amount_subtotal);
   $column_data{tax} 			= rpt_dec($tax_subtotal);
   $column_data{total} 			= rpt_dec($total_subtotal);
   $column_data{cogs} 			= rpt_dec($cogs_subtotal);
   $column_data{employee}    		= rpt_txt('&nbsp;');

   # Print subtotal value of sorted column as heading
   $column_data{$form->{sort}}		= rpt_txt($groupbreak) if $form->{l_subtotalonly};
	
   my $markup = 0;
   if ($form->{l_subtotal}){
   	if ($amount_subtotal > 0){
     	   $markup = (($amount_subtotal - $cogs_subtotal) * 100)/$amount_subtotal;
   	}
   	$column_data{markup} 		= rpt_dec($markup);

	# print last subtotal
	print "<tr valign=top class=listsubtotal>";
	for (@column_index) { print "\n$column_data{$_}" }
	print "</tr>";
   }

   # grand total
   $column_data{qty} 			= rpt_dec($qty_total);
   $column_data{sellprice} 		= rpt_txt('&nbsp;');
   $column_data{amount} 		= rpt_dec($amount_total);
   $column_data{tax} 			= rpt_dec($tax_total);
   $column_data{total} 			= rpt_dec($total_total);
   $column_data{cogs} 			= rpt_dec($cogs_total);
   $markup = 0;
   if ($amount_total > 0){
      $markup = (($amount_total - $cogs_total) * 100)/$amount_total;
   }
   $column_data{markup} 		= rpt_dec($markup);

   # print footer
   print "<tr valign=top class=listtotal>";
   for (@column_index) { print "\n$column_data{$_}" }
   print "</tr>";

   print qq|</table>|;
   $sth->finish;
   $dbh->disconnect;
}

#===================================
#
# Stock Assemblies Transactions
#
#==================================
#-------------------------------
sub build_search {
   $form->{title} = $locale->text('Stock Assembly');
   &print_title;

   &start_form;
   &start_table;

   &bld_department;
   &bld_warehouse;
   &bld_partsgroup;

   &print_text('reference', $locale->text('Reference'), 15);
   &print_date('datefrom', $locale->text('From'));
   &print_date('dateto', $locale->text('To'));

   &print_text('partnumber', $locale->text('Number'), 30);
   #&print_select('partsgroup', $locale->text('Group'));
   &print_select('department', $locale->text('Department'));
   &print_select('warehouse', $locale->text('Warehouse'));
 
   print qq|<tr><th align=right>| . $locale->text('Include in Report') . qq|</th><td>|;

   &print_radio;
   &print_checkbox('l_no', $locale->text('No.'), '', '');
   &print_checkbox('l_reference', $locale->text('Reference'), 'checked', '');
   &print_checkbox('l_transdate', $locale->text('Date'), 'checked', '');
   &print_checkbox('l_department', $locale->text('Warehouse'), 'checked', '');
   &print_checkbox('l_warehouse', $locale->text('Warehouse'), 'checked', '<br />');
   &print_checkbox('l_partnumber', $locale->text('Number'), 'checked', '');
   &print_checkbox('l_description', $locale->text('Description'), 'checked', '');
   &print_checkbox('l_qty', $locale->text('Qty'), 'checked', '');
   &print_checkbox('l_unit', $locale->text('Unit'), 'checked', '<br />');
   &print_checkbox('l_subtotal', $locale->text('Subtotal'), '', '');
   &print_checkbox('l_csv', $locale->text('CSV'), '', '');
   #&print_checkbox('l_sql', $locale->text('SQL'), '');
   print qq|</td></tr>|;
   &end_table;
   print('<hr size=3 noshade>');
   $form->{nextsub} = 'build_list';
   &print_hidden('nextsub');
   &add_button($locale->text('Continue'));
   &end_form;
}

#-------------------------------
sub build_list {
   # callback to report list
   my $callback = qq|$form->{script}?action=build_list|;
   for (qw(path login sessionid)) { $callback .= "&$_=$form->{$_}" }

   &split_combos('department,warehouse');
   $form->{department_id} *= 1;
   $form->{warehouse_id} *= 1;
   #$form->{partsgroup_id} *= 1;
   $reference = $form->like(lc $form->{reference});
   $partnumber = $form->like(lc $form->{partnumber});
   
   my $where = qq| (1 = 1)|;
   $where .= qq| AND (LOWER(b.reference) LIKE '$reference')| if $form->{reference};
   #$where .= qq| AND (p.partsgroup_id = $form->{partsgroup_id})| if $form->{partsgroup};
   $where .= qq| AND (b.department_id = $form->{department_id})| if $form->{department};
   $where .= qq| AND (b.warehouse_id = $form->{warehouse_id})| if $form->{warehouse};
   $where .= qq| AND (b.transdate >= '$form->{datefrom}')| if $form->{datefrom};
   $where .= qq| AND (b.transdate <= '$form->{dateto}')| if $form->{dateto};
   $where .= qq| AND (LOWER(p.partnumber) LIKE '$partnumber')| if $form->{partnumber} and !$form->{summary};

   @columns = qw(id reference transdate department warehouse partnumber description qty unit);
   # if this is first time we are running this report.
   $form->{sort} = 'reference' if !$form->{sort};
   $form->{oldsort} = 'none' if !$form->{oldsort};
   $form->{direction} = 'ASC' if !$form->{direction};
   @columns = $form->sort_columns(@columns);

   my %ordinal = (	id => 1,
			reference => 2,
			transdate => 3,
			department => 4,
			warehouse => 5,
			partnumber => 6,
			description => 7,
			amount => 8
   );
   my $sort_order = $form->sort_order(\@columns, \%ordinal);

   # No. columns should always come first
   splice @columns, 0, 0, 'no';

   # Select columns selected for report display
   foreach $item (@columns) {
     if ($form->{"l_$item"} eq "Y") {
       push @column_index, $item;

       # add column to href and callback
       $callback .= "&l_$item=Y";
     }
   }
   $callback .= "&l_subtotal=$form->{l_subtotal}";
   my $href = $callback;
   $form->{callback} = $form->escape($callback,1);

   if ($form->{summary}){
   	$query = qq|SELECT 
			b.id, 
			b.reference,
			b.transdate,
			w.description AS warehouse,	
			d.description AS department,
			p.partnumber,
			p.description,
			i.qty,
			p.unit
			FROM build b
			LEFT JOIN department d ON (d.id = b.department_id)
			LEFT JOIN warehouse w ON (w.id = b.warehouse_id)
			JOIN inventory i ON (i.trans_id = b.id)
			JOIN parts p ON (p.id = i.parts_id)
			WHERE $where AND assembly
			ORDER BY $form->{sort} $form->{direction}, i.linetype DESC|;
   } else {
   	$query = qq|SELECT 
			b.id, 
			b.reference,
			b.transdate,
			w.description AS warehouse,	
			d.description AS department,
			p.partnumber,
			p.description,
			i.qty,
			p.unit
			FROM build b
			LEFT JOIN department d ON (d.id = b.department_id)
			LEFT JOIN warehouse w ON (w.id = b.warehouse_id)
			JOIN inventory i ON (i.trans_id = b.id)
			JOIN parts p ON (p.id = i.parts_id)
			WHERE $where
			ORDER BY $form->{sort} $form->{direction}, i.linetype DESC|;
   }
   # store oldsort/direction information
   $href .= "&direction=$form->{direction}&oldsort=$form->{sort}";

   $column_header{no}   		= rpt_hdr('no', $locale->text('No.'));
   $column_header{reference} 		= rpt_hdr('reference', $locale->text('Reference'), $href);
   $column_header{transdate} 		= rpt_hdr('transdate', $locale->text('Date'), $href);
   $column_header{department} 		= rpt_hdr('department', $locale->text('Department'), $href);
   $column_header{warehouse} 		= rpt_hdr('warehouse', $locale->text('Warehouse'), $href);
   $column_header{partnumber} 		= rpt_hdr('partnumber', $locale->text('Number'), $href);
   $column_header{description} 		= rpt_hdr('description', $locale->text('Description'), $href);
   $column_header{qty}  		= rpt_hdr('qty', $locale->text('Qty'), $href);
   $column_header{unit}  		= rpt_hdr('unit', $locale->text('Unit'), $href);

   $form->error($query) if $form->{l_sql};
   $dbh = $form->dbconnect(\%myconfig);
   my %defaults = $form->get_defaults($dbh, \@{['precision', 'company']});
   for (keys %defaults) { $form->{$_} = $defaults{$_} }

   if ($form->{l_csv} eq 'Y'){
	&export_to_csv($dbh, $query, 'stock_assembly');
	exit;
   }
   $sth = $dbh->prepare($query);
   $sth->execute || $form->dberror($query);

   $form->{title} = $locale->text('Stock Assembly');
   &print_title;
   &print_criteria('datefrom', $locale->text('From'));
   &print_criteria('dateto', $locale->text('To'));
   &print_criteria('reference',$locale->text('Reference'));
   &print_criteria('department_name', $locale->text('Department'));
   &print_criteria('warehouse_name', $locale->text('Warehouse'));
   print qq|<table width=100%><tr class=listheading>|;
   # print header
   for (@column_index) { print "\n$column_header{$_}" }
   print qq|</tr>|; 

   # Subtotal and total variables
   my $qty_subtotal = 0;
   my $qty_total = 0;

   # print data
   my $i = 1; my $no = 1;
   my $groupbreak = 'none';
   while (my $ref = $sth->fetchrow_hashref(NAME_lc)){
   	$form->{link} = qq|$form->{script}?action=edit&id=$ref->{id}&path=$form->{path}&login=$form->{login}&sessionid=$form->{sessionid}&callback=$form->{callback}|;
	$groupbreak = $ref->{$form->{sort}} if $groupbreak eq 'none';
	if ($form->{l_subtotal}){
	   if ($groupbreak ne $ref->{$form->{sort}}){
		$groupbreak = $ref->{$form->{sort}};
		# prepare data for footer
   		$column_data{no}   		= rpt_txt('&nbsp;');
   		$column_data{reference}  	= rpt_txt('&nbsp;');
   		$column_data{transdate}  	= rpt_txt('&nbsp;');
   		$column_data{department}  	= rpt_txt('&nbsp;');
   		$column_data{warehouse}  	= rpt_txt('&nbsp;');
   		$column_data{partnumber}  	= rpt_txt('&nbsp;');
   		$column_data{description} 	= rpt_txt('&nbsp;');
   		$column_data{qty} 		= rpt_dec($qty_subtotal);
   		$column_data{unit} 		= rpt_txt('&nbsp;');
		# print footer
		print "<tr valign=top class=listsubtotal>";
		for (@column_index) { print "\n$column_data{$_}" }
		print "</tr>";
		$qty_subtotal = 0;
	   }
	}
	$column_data{no}   		= rpt_txt($no);
   	$column_data{reference}		= rpt_txt($ref->{reference});
   	$column_data{transdate}		= rpt_txt($ref->{transdate});
   	$column_data{department}	= rpt_txt($ref->{department});
   	$column_data{warehouse}		= rpt_txt($ref->{warehouse});
   	$column_data{partnumber}	= rpt_txt($ref->{partnumber});
   	$column_data{description} 	= rpt_txt($ref->{description});
   	$column_data{qty}    		= rpt_dec($ref->{qty});
   	$column_data{unit}    		= rpt_txt($ref->{unit});

	print "<tr valign=top class=listrow$i>";
	for (@column_index) { print "\n$column_data{$_}" }
	print "</tr>";
	$i++; $i %= 2; $no++;

	$qty_subtotal += $ref->{qty};
	$qty_total += $ref->{qty};
   }

   # prepare data for footer
   $column_data{no}   		= rpt_txt('&nbsp;');
   $column_data{reference}  	= rpt_txt('&nbsp;');
   $column_data{transdate}  	= rpt_txt('&nbsp;');
   $column_data{department}  	= rpt_txt('&nbsp;');
   $column_data{warehouse}  	= rpt_txt('&nbsp;');
   $column_data{partnumber}  	= rpt_txt('&nbsp;');
   $column_data{description} 	= rpt_txt('&nbsp;');
   $column_data{qty} 		= rpt_dec($qty_subtotal);
   $column_data{unit} 		= rpt_txt('&nbsp;');

   if ($form->{l_subtotal}){
	# print last subtotal
	print "<tr valign=top class=listsubtotal>";
	for (@column_index) { print "\n$column_data{$_}" }
	print "</tr>";
   }

   # grand total
   $column_data{qty} = rpt_dec($qty_total);

   # print footer
   print "<tr valign=top class=listtotal>";
   for (@column_index) { print "\n$column_data{$_}" }
   print "</tr>";

   print qq|</table>|;
   $sth->finish;
   $dbh->disconnect;
}

#===================================
#
# Projects report
#
#==================================
#-------------------------------
sub projects_search {
   $form->{title} = $locale->text('Projects Summary');
   &print_title;

   &start_form;
   &start_table;

   &bld_department;

   &print_text('projectnumber', $locale->text('Project Number'), 30);
   &print_text('description', $locale->text('Description'));
   &print_select('department', $locale->text('Department'));
   &print_date('datefrom', $locale->text('From'));
   &print_date('dateto', $locale->text('To'));
   &print_period;
 
   print qq|<tr><th align=right>| . $locale->text('Include in Report') . qq|</th><td>|;

   &print_checkbox('l_no', $locale->text('No.'), '', '');
   &print_checkbox('l_projectnumber', $locale->text('Project Number'), 'checked', '');
   &print_checkbox('l_description', $locale->text('Description'), 'checked', '');
   &print_checkbox('l_startdate', $locale->text('From'), 'checked', '');
   &print_checkbox('l_enddate', $locale->text('To'), 'checked', '<br>');
   &print_checkbox('l_income', $locale->text('Income'), 'checked', '');
   &print_checkbox('l_expenses', $locale->text('Expenses'), 'checked', '');
   &print_checkbox('l_net', $locale->text('Net'), 'checked', '<br>');
   &print_checkbox('l_subtotal', $locale->text('Subtotal'), '', '');
   &print_checkbox('l_csv', $locale->text('CSV'), '', '');
   #&print_checkbox('l_sql', $locale->text('SQL'), '');
   print qq|</td></tr>|;
   &end_table;
   print('<hr size=3 noshade>');
   $form->{nextsub} = 'projects_list';
   &print_hidden('nextsub');
   &add_button($locale->text('Continue'));
   &end_form;
}

#-------------------------------
sub projects_list {
  # callback to report list
   my $callback = qq|$form->{script}?action=projects_list|;
   for (qw(path login sessionid)) { $callback .= "&$_=$form->{$_}" }

   &split_combos('department,warehouse,partsgroup');
   $form->{department_id} *= 1;
   $projectnumber = $form->like(lc $form->{projectnumber});
   $description = $form->like(lc $form->{description});
 
  ($form->{datefrom}, $form->{dateto}) = $form->from_to($form->{year}, $form->{month}, $form->{interval}) if $form->{year} && $form->{month}; 
  
   $datefrom = $locale->date(\%myconfig, $form->{datefrom}, 1);
   $dateto = $locale->date(\%myconfig, $form->{dateto}, 1);

   my $where = qq| (1 = 1)|;
   my $subwhere;
   $where .= qq| AND (LOWER(p.projectnumber) LIKE '$projectnumber')| if $form->{projectnumber};
   $where .= qq| AND (LOWER(p.description) LIKE '$description')| if $form->{description};

   $subwhere .= qq| AND (ac.transdate >= '$form->{datefrom}')| if $form->{datefrom};
   $subwhere .= qq| AND (ac.transdate <= '$form->{dateto}')| if $form->{dateto};
   $subwhere .= qq| AND (ac.trans_id IN (SELECT trans_id FROM dpt_trans WHERE department_id = $form->{department_id}))| if $form->{department};

   @columns = qw(id projectnumber description startdate enddate income expenses net);
   # if this is first time we are running this report.
   $form->{sort} = 'projectnumber' if !$form->{sort};
   $form->{oldsort} = 'none' if !$form->{oldsort};
   $form->{direction} = 'ASC' if !$form->{direction};
   @columns = $form->sort_columns(@columns);

   my %ordinal = (	id => 1,
			projectnumber => 2,
			description => 3,
			startdate => 4,
			enddate => 5,
			income => 6,
			expenses => 7,
			net => 8,
   );
   my $sort_order = $form->sort_order(\@columns, \%ordinal);

   # No. columns should always come first
   splice @columns, 0, 0, 'no';

   # Select columns selected for report display
   foreach $item (@columns) {
     if ($form->{"l_$item"} eq "Y") {
       push @column_index, $item;

       # add column to href and callback
       $callback .= "&l_$item=Y";
     }
   }
   $callback .= "&l_subtotal=$form->{l_subtotal}";
   my $href = $callback;
   $form->{callback} = $form->escape($callback,1);

   $query = qq|SELECT 
		p.id, 
		p.projectnumber, 
		p.description, 
		p.startdate,
		p.enddate,

		(SELECT SUM(amount) 
		 FROM acc_trans ac
		 JOIN chart c ON (c.id = ac.chart_id)
		 WHERE c.category = 'I'
		 AND ac.project_id = p.id
		 $subwhere) AS income,

		(SELECT SUM(0-amount) 
		 FROM acc_trans ac
		 JOIN chart c ON (c.id = ac.chart_id)
		 WHERE c.category = 'E'
		 AND ac.project_id = p.id
		 $subwhere) AS expenses

		FROM project p
		WHERE $where
		ORDER BY $form->{sort} $form->{direction}|;

   # store oldsort/direction information
   $href .= "&direction=$form->{direction}&oldsort=$form->{sort}";

   $column_header{no}   		= rpt_hdr('no', $locale->text('No.'));
   $column_header{projectnumber} 	= rpt_hdr('projectnumber', $locale->text('Number'), $href);
   $column_header{description} 		= rpt_hdr('description', $locale->text('Description'), $href);
   $column_header{startdate}  		= rpt_hdr('startdate', $locale->text('Startdate'), $href);
   $column_header{enddate}  		= rpt_hdr('enddate', $locale->text('Enddate'), $href);
   $column_header{income}  		= rpt_hdr('income', $locale->text('Income'), $href);
   $column_header{expenses}  		= rpt_hdr('expenses', $locale->text('Expenses'), $href);
   $column_header{net}  		= rpt_hdr('net', $locale->text('Income/(Loss)'));

   $form->error($query) if $form->{l_sql};
   $dbh = $form->dbconnect(\%myconfig);
   my %defaults = $form->get_defaults($dbh, \@{['precision', 'company']});
   for (keys %defaults) { $form->{$_} = $defaults{$_} }

   if ($form->{l_csv} eq 'Y'){
	&export_to_csv($dbh, $query, 'parts_onhand');
	exit;
   }
   $sth = $dbh->prepare($query);
   $sth->execute || $form->dberror($query);

   $form->{title} = $locale->text('Projects Summary');
   &print_title;
   &print_criteria('projectnumber', $locale->text('Project Number'));
   &print_criteria('description', $locale->text('Description'));
   &print_criteria('department_name', $locale->text('Department'));

   print $locale->text('From') . ' ' . $datefrom . "<br />";
   print $locale->text('To') . ' ' . $dateto;

   print qq|<table width=100%><tr class=listheading>|;
   # print header
   for (@column_index) { print "\n$column_header{$_}" }
   print qq|</tr>|; 

   # Subtotal and total variables
   my $qty_subtotal = 0;
   my $qty_total = 0;
   my $amount_subtotal = 0;
   my $amount_total = 0;

   # print data
   my $i = 1; my $no = 1;
   my $groupbreak = 'none';
   $form->{accounttype} = 'standard';
   while (my $ref = $sth->fetchrow_hashref(NAME_lc)){
   	$form->{link} = qq|rp.pl?action=continue&nextsub=generate_projects&projectnumber=$ref->{projectnumber}--$ref->{id}|;
        for (qw(accounttype datefrom dateto l_subtotal path login)){ $form->{link} .= "&$_=$form->{$_}" }
	$groupbreak = $ref->{$form->{sort}} if $groupbreak eq 'none';
	if ($form->{l_subtotal}){
	   if ($groupbreak ne $ref->{$form->{sort}}){
		$groupbreak = $ref->{$form->{sort}};
		# prepare data for footer

		for (@column_index) { $column_data{$_} = rpt_txt('&nbsp;') };
   		$column_data{income} 	= rpt_dec($income_subtotal);
   		$column_data{expenses} 	= rpt_dec($expenses_subtotal);
   		$column_data{net} 	= rpt_dec($income_subtotal - $expenses_subtotal);

		# print footer
		print "<tr valign=top class=listsubtotal>";
		for (@column_index) { print "\n$column_data{$_}" }
		print "</tr>";

		$income_subtotal = 0;
		$expenses_subtotal = 0;
		$net_subtotal = 0;
	   }
	}

	$column_data{no}   		= rpt_txt($no);
   	$column_data{projectnumber}	= rpt_txt($ref->{projectnumber}, $form->{link});
   	$column_data{description}	= rpt_txt($ref->{description});
   	$column_data{startdate} 	= rpt_txt($ref->{startdate});
   	$column_data{enddate}    	= rpt_txt($ref->{enddate});
   	$column_data{income}    	= rpt_dec($ref->{income});
   	$column_data{expenses}    	= rpt_dec($ref->{expenses});
   	$column_data{net}    		= rpt_dec($ref->{income} - $ref->{expenses});

	print "<tr valign=top class=listrow$i>";
	for (@column_index) { print "\n$column_data{$_}" }
	print "</tr>";
	$i++; $i %= 2; $no++;

	$income_subtotal += $ref->{income};
	$income_total += $ref->{income};
	$expenses_subtotal += $ref->{expenses};
	$expenses_total += $ref->{expenses};
   }

   # prepare data for footer
   for (@column_index) { $column_data{$_} = rpt_txt('&nbsp;') };
   $column_data{income}   = rpt_dec($income_subtotal);
   $column_data{expenses} = rpt_dec($expenses_subtotal);
   $column_data{net} 	  = rpt_dec($income_subtotal - $expenses_subtotal);

   if ($form->{l_subtotal}){
	# print last subtotal
	print "<tr valign=top class=listsubtotal>";
	for (@column_index) { print "\n$column_data{$_}" }
	print "</tr>";
   }
   # grand total
   $column_data{income}   = rpt_dec($income_total);
   $column_data{expenses} = rpt_dec($expenses_total);
   $column_data{net} 	  = rpt_dec($income_total - $expenses_total);

   # print footer
   print "<tr valign=top class=listtotal>";
   for (@column_index) { print "\n$column_data{$_}" }
   print "</tr>";

   print qq|</table>|;
   $sth->finish;
   $dbh->disconnect;
}

#######
## EOF
#######

