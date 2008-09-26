#=====================================================================
# SQL-Ledger ERP
# Copyright (C) 2006
#
#  Author: DWS Systems Inc.
#     Web: http://www.sql-ledger.com
#
#======================================================================
#
# backend code for reports
#
#======================================================================

package RP;


sub yearend_statement {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  # if todate < existing yearends, delete GL and yearends
  my $query = qq|SELECT trans_id FROM yearend
                 WHERE transdate >= '$form->{todate}'|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);
  
  my @trans_id = ();
  my $id;
  while (($id) = $sth->fetchrow_array) {
    push @trans_id, $id;
  }
  $sth->finish;

  $query = qq|DELETE FROM gl
              WHERE id = ?|;
  $sth = $dbh->prepare($query) || $form->dberror($query);

  $query = qq|DELETE FROM acc_trans
              WHERE trans_id = ?|;
  my $ath = $dbh->prepare($query) || $form->dberror($query);
	      
  foreach $id (@trans_id) {
    $sth->execute($id);
    $ath->execute($id);

    $sth->finish;
    $ath->finish;
  }
  
  
  my $last_period = 0;
  my @categories = qw(I E);
  my $category;

  $form->{decimalplaces} *= 1;

  &get_accounts($dbh, 0, $form->{fromdate}, $form->{todate}, $form, \@categories);
  
  # disconnect
  $dbh->disconnect;


  # now we got $form->{I}{accno}{ }
  # and $form->{E}{accno}{  }
  
  my %account = ( 'I' => { 'label' => 'income',
                           'labels' => 'income',
			   'ml' => 1 },
		  'E' => { 'label' => 'expense',
		           'labels' => 'expenses',
			   'ml' => -1 }
		);
  
  foreach $category (@categories) {
    foreach $key (sort keys %{ $form->{$category} }) {
      if ($form->{$category}{$key}{charttype} eq 'A') {
	$form->{"total_$account{$category}{labels}_this_period"} += $form->{$category}{$key}{this} * $account{$category}{ml};
      }
    }
  }


  # totals for income and expenses
  $form->{total_income_this_period} = $form->round_amount($form->{total_income_this_period}, $form->{decimalplaces});
  $form->{total_expenses_this_period} = $form->round_amount($form->{total_expenses_this_period}, $form->{decimalplaces});

  # total for income/loss
  $form->{total_this_period} = $form->{total_income_this_period} - $form->{total_expenses_this_period};
  
}


sub income_statement {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $last_period = 0;
  my @categories = qw(I E);
  my $category;

  $form->{decimalplaces} *= 1;

  if (! ($form->{fromdate} || $form->{todate})) {
    if ($form->{fromyear} && $form->{frommonth}) {
      ($form->{fromdate}, $form->{todate}) = $form->from_to($form->{fromyear}, $form->{frommonth}, $form->{interval});
    }
  }
  
  &get_accounts($dbh, $last_period, $form->{fromdate}, $form->{todate}, $form, \@categories, 1);
  
  if (! ($form->{comparefromdate} || $form->{comparetodate})) {
    if ($form->{compareyear} && $form->{comparemonth}) {
      ($form->{comparefromdate}, $form->{comparetodate}) = $form->from_to($form->{compareyear}, $form->{comparemonth}, $form->{interval});
    }
  }

  # if there are any compare dates
  if ($form->{comparefromdate} || $form->{comparetodate}) {
    $last_period = 1;

    &get_accounts($dbh, $last_period, $form->{comparefromdate}, $form->{comparetodate}, $form, \@categories, 1);
  }  

  my %defaults = $form->get_defaults($dbh, \@{['company','address','businessnumber']});
  for (keys %defaults) { $form->{$_} = $defaults{$_} }
  
  # disconnect
  $dbh->disconnect;


  # now we got $form->{I}{accno}{ }
  # and $form->{E}{accno}{  }
  
  my %account = ( 'I' => { 'label' => 'income',
                           'labels' => 'income',
			   'ml' => 1 },
		  'E' => { 'label' => 'expense',
		           'labels' => 'expenses',
			   'ml' => -1 }
		);
  
  my $str;
  
  foreach $category (@categories) {
    
    foreach $key (sort keys %{ $form->{$category} }) {
      # push description onto array
      
      $str = ($form->{l_heading}) ? $form->{padding} : "";
      
      if ($form->{$category}{$key}{charttype} eq "A") {
	$str .= ($form->{l_accno}) ? "$form->{$category}{$key}{accno} - $form->{$category}{$key}{description}" : "$form->{$category}{$key}{description}";
      }
      if ($form->{$category}{$key}{charttype} eq "H") {
	if ($account{$category}{subtotal} && $form->{l_subtotal}) {
	  $dash = "- ";
	  push(@{$form->{"$account{$category}{label}_account"}}, "$str$form->{bold}$account{$category}{subdescription}$form->{endbold}");
	  push(@{$form->{"$account{$category}{labels}_this_period"}}, $form->format_amount($myconfig, $account{$category}{subthis} * $account{$category}{ml}, $form->{decimalplaces}, $dash));
	  
	  if ($last_period) {
	    push(@{$form->{"$account{$category}{labels}_last_period"}}, $form->format_amount($myconfig, $account{$category}{sublast} * $account{$category}{ml}, $form->{decimalplaces}, $dash));
	  }
	  
	}
	
	$str = "$form->{br}$form->{bold}$form->{$category}{$key}{description}$form->{endbold}";

	$account{$category}{subthis} = $form->{$category}{$key}{this};
	$account{$category}{sublast} = $form->{$category}{$key}{last};
	$account{$category}{subdescription} = $form->{$category}{$key}{description};
	$account{$category}{subtotal} = 1;

	$form->{$category}{$key}{this} = 0;
	$form->{$category}{$key}{last} = 0;

	next unless $form->{l_heading};

	$dash = " ";
      }
      
      push(@{$form->{"$account{$category}{label}_account"}}, $str);
      
      if ($form->{$category}{$key}{charttype} eq 'A') {
	$form->{"total_$account{$category}{labels}_this_period"} += $form->{$category}{$key}{this} * $account{$category}{ml};
	$dash = "- ";
      }
      
      push(@{$form->{"$account{$category}{labels}_this_period"}}, $form->format_amount($myconfig, $form->{$category}{$key}{this} * $account{$category}{ml}, $form->{decimalplaces}, $dash));
      
      # add amount or - for last period
      if ($last_period) {
	$form->{"total_$account{$category}{labels}_last_period"} += $form->{$category}{$key}{last} * $account{$category}{ml};

	push(@{$form->{"$account{$category}{labels}_last_period"}}, $form->format_amount($myconfig,$form->{$category}{$key}{last} * $account{$category}{ml}, $form->{decimalplaces}, $dash));
      }
    }

    $str = ($form->{l_heading}) ? $form->{padding} : "";
    if ($account{$category}{subtotal} && $form->{l_subtotal}) {
      push(@{$form->{"$account{$category}{label}_account"}}, "$str$form->{bold}$account{$category}{subdescription}$form->{endbold}");
      push(@{$form->{"$account{$category}{labels}_this_period"}}, $form->format_amount($myconfig, $account{$category}{subthis} * $account{$category}{ml}, $form->{decimalplaces}, $dash));

      if ($last_period) {
	push(@{$form->{"$account{$category}{labels}_last_period"}}, $form->format_amount($myconfig, $account{$category}{sublast} * $account{$category}{ml}, $form->{decimalplaces}, $dash));
      }
    }
      
  }


  # totals for income and expenses
  $form->{total_income_this_period} = $form->round_amount($form->{total_income_this_period}, $form->{decimalplaces});
  $form->{total_expenses_this_period} = $form->round_amount($form->{total_expenses_this_period}, $form->{decimalplaces});

  # total for income/loss
  $form->{total_this_period} = $form->{total_income_this_period} - $form->{total_expenses_this_period};
  
  if ($last_period) {
    # total for income/loss
    $form->{total_last_period} = $form->format_amount($myconfig, $form->{total_income_last_period} - $form->{total_expenses_last_period}, $form->{decimalplaces}, "- ");
    
    # totals for income and expenses for last_period
    $form->{total_income_last_period} = $form->format_amount($myconfig, $form->{total_income_last_period}, $form->{decimalplaces}, "- ");
    $form->{total_expenses_last_period} = $form->format_amount($myconfig, $form->{total_expenses_last_period}, $form->{decimalplaces}, "- ");

  }


  $form->{total_income_this_period} = $form->format_amount($myconfig,$form->{total_income_this_period}, $form->{decimalplaces}, "- ");
  $form->{total_expenses_this_period} = $form->format_amount($myconfig,$form->{total_expenses_this_period}, $form->{decimalplaces}, "- ");
  $form->{total_this_period} = $form->format_amount($myconfig,$form->{total_this_period}, $form->{decimalplaces}, "- ");

}


sub balance_sheet {
  my ($self, $myconfig, $form) = @_;
  
  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $last_period = 0;
  my @categories = qw(A L Q);

  my $null;
  
  if ($form->{asofdate}) {
    if ($form->{asofyear} && $form->{asofmonth}) {
      if ($form->{asofdate} !~ /\W/) {
	$form->{asofdate} = "$form->{asofyear}$form->{asofmonth}$form->{asofdate}";
      }
    }
  } else {
    if ($form->{asofyear} && $form->{asofmonth}) {
      ($null, $form->{asofdate}) = $form->from_to($form->{asofyear}, $form->{asofmonth});
    }
  }
  
  # if there are any dates construct a where
  if ($form->{asofdate}) {
    
    $form->{this_period} = "$form->{asofdate}";
    $form->{period} = "$form->{asofdate}";
    
  }

  $form->{decimalplaces} *= 1;

  &get_accounts($dbh, $last_period, "", $form->{asofdate}, $form, \@categories, 1);
  
  if ($form->{compareasofdate}) {
    if ($form->{compareasofyear} && $form->{compareasofmonth}) {
      if ($form->{compareasofdate} !~ /\W/) {
	$form->{compareasofdate} = "$form->{compareasofyear}$form->{compareasofmonth}$form->{compareasofdate}";
      }
    }
  } else {
    if ($form->{compareasofyear} && $form->{compareasofmonth}) {
      ($null, $form->{compareasofdate}) = $form->from_to($form->{compareasofyear}, $form->{compareasofmonth});
    }
  }
  
  # if there are any compare dates
  if ($form->{compareasofdate}) {

    $last_period = 1;
    &get_accounts($dbh, $last_period, "", $form->{compareasofdate}, $form, \@categories, 1);
  
    $form->{last_period} = "$form->{compareasofdate}";

  }  

  my %defaults = $form->get_defaults($dbh, \@{['company','address','businessnumber']});
  for (keys %defaults) { $form->{$_} = $defaults{$_} }
  
  # disconnect
  $dbh->disconnect;


  # now we got $form->{A}{accno}{ }    assets
  # and $form->{L}{accno}{ }           liabilities
  # and $form->{Q}{accno}{ }           equity
  # build asset accounts
  
  my $str;
  my $key;
  
  my %account  = ( 'A' => { 'label' => 'asset',
                            'labels' => 'assets',
			    'ml' => -1 },
		   'L' => { 'label' => 'liability',
		            'labels' => 'liabilities',
			    'ml' => 1 },
		   'Q' => { 'label' => 'equity',
		            'labels' => 'equity',
			    'ml' => 1 }
		);	    


   foreach $category (@categories) {			    

    foreach $key (sort keys %{ $form->{$category} }) {

      $str = ($form->{l_heading}) ? $form->{padding} : "";

      if ($form->{$category}{$key}{charttype} eq "A") {
	$str .= ($form->{l_accno}) ? "$form->{$category}{$key}{accno} - $form->{$category}{$key}{description}" : "$form->{$category}{$key}{description}";
      }
      if ($form->{$category}{$key}{charttype} eq "H") {
	if ($account{$category}{subtotal} && $form->{l_subtotal}) {
	  $dash = "- ";
	  push(@{$form->{"$account{$category}{label}_account"}}, "$str$form->{bold}$account{$category}{subdescription}$form->{endbold}");
	  push(@{$form->{"$account{$category}{label}_this_period"}}, $form->format_amount($myconfig, $account{$category}{subthis} * $account{$category}{ml}, $form->{decimalplaces}, $dash));
	  
	  if ($last_period) {
	    push(@{$form->{"$account{$category}{label}_last_period"}}, $form->format_amount($myconfig, $account{$category}{sublast} * $account{$category}{ml}, $form->{decimalplaces}, $dash));
	  }
	}

	$str = "$form->{bold}$form->{$category}{$key}{description}$form->{endbold}";
	
	$account{$category}{subthis} = $form->{$category}{$key}{this};
	$account{$category}{sublast} = $form->{$category}{$key}{last};
	$account{$category}{subdescription} = $form->{$category}{$key}{description};
	$account{$category}{subtotal} = 1;
	
	$form->{$category}{$key}{this} = 0;
	$form->{$category}{$key}{last} = 0;

	next unless $form->{l_heading};

	$dash = " ";
      }
      
      # push description onto array
      push(@{$form->{"$account{$category}{label}_account"}}, $str);
      
      if ($form->{$category}{$key}{charttype} eq 'A') {
	$form->{"total_$account{$category}{labels}_this_period"} += $form->{$category}{$key}{this} * $account{$category}{ml};
	$dash = "- ";
      }

      push(@{$form->{"$account{$category}{label}_this_period"}}, $form->format_amount($myconfig, $form->{$category}{$key}{this} * $account{$category}{ml}, $form->{decimalplaces}, $dash));
      
      if ($last_period) {
	$form->{"total_$account{$category}{labels}_last_period"} += $form->{$category}{$key}{last} * $account{$category}{ml};

	push(@{$form->{"$account{$category}{label}_last_period"}}, $form->format_amount($myconfig, $form->{$category}{$key}{last} * $account{$category}{ml}, $form->{decimalplaces}, $dash));
      }
    }

    $str = ($form->{l_heading}) ? $form->{padding} : "";
    if ($account{$category}{subtotal} && $form->{l_subtotal}) {
      push(@{$form->{"$account{$category}{label}_account"}}, "$str$form->{bold}$account{$category}{subdescription}$form->{endbold}");
      push(@{$form->{"$account{$category}{label}_this_period"}}, $form->format_amount($myconfig, $account{$category}{subthis} * $account{$category}{ml}, $form->{decimalplaces}, $dash));
      
      if ($last_period) {
	push(@{$form->{"$account{$category}{label}_last_period"}}, $form->format_amount($myconfig, $account{$category}{sublast} * $account{$category}{ml}, $form->{decimalplaces}, $dash));
      }
    }

  }

  
  # totals for assets, liabilities
  $form->{total_assets_this_period} = $form->round_amount($form->{total_assets_this_period}, $form->{decimalplaces});
  $form->{total_liabilities_this_period} = $form->round_amount($form->{total_liabilities_this_period}, $form->{decimalplaces});
  $form->{total_equity_this_period} = $form->round_amount($form->{total_equity_this_period}, $form->{decimalplaces});

  # calculate earnings
  $form->{earnings_this_period} = $form->{total_assets_this_period} - $form->{total_liabilities_this_period} - $form->{total_equity_this_period};

  push(@{$form->{equity_this_period}}, $form->format_amount($myconfig, $form->{earnings_this_period}, $form->{decimalplaces}, "- "));
  
  $form->{total_equity_this_period} = $form->round_amount($form->{total_equity_this_period} + $form->{earnings_this_period}, $form->{decimalplaces});
  
  # add liability + equity
  $form->{total_this_period} = $form->format_amount($myconfig, $form->{total_liabilities_this_period} + $form->{total_equity_this_period}, $form->{decimalplaces}, "- ");


  if ($last_period) {
    # totals for assets, liabilities
    $form->{total_assets_last_period} = $form->round_amount($form->{total_assets_last_period}, $form->{decimalplaces});
    $form->{total_liabilities_last_period} = $form->round_amount($form->{total_liabilities_last_period}, $form->{decimalplaces});
    $form->{total_equity_last_period} = $form->round_amount($form->{total_equity_last_period}, $form->{decimalplaces});

    # calculate retained earnings
    $form->{earnings_last_period} = $form->{total_assets_last_period} - $form->{total_liabilities_last_period} - $form->{total_equity_last_period};

    push(@{$form->{equity_last_period}}, $form->format_amount($myconfig,$form->{earnings_last_period}, $form->{decimalplaces}, "- "));
    
    $form->{total_equity_last_period} = $form->round_amount($form->{total_equity_last_period} + $form->{earnings_last_period}, $form->{decimalplaces});

    # add liability + equity
    $form->{total_last_period} = $form->format_amount($myconfig, $form->{total_liabilities_last_period} + $form->{total_equity_last_period}, $form->{decimalplaces}, "- ");

  }

  
  $form->{total_liabilities_last_period} = $form->format_amount($myconfig, $form->{total_liabilities_last_period}, $form->{decimalplaces}, "- ") if ($form->{total_liabilities_last_period});
  
  $form->{total_equity_last_period} = $form->format_amount($myconfig, $form->{total_equity_last_period}, $form->{decimalplaces}, "- ") if ($form->{total_equity_last_period});
  
  $form->{total_assets_last_period} = $form->format_amount($myconfig, $form->{total_assets_last_period}, $form->{decimalplaces}, "- ") if ($form->{total_assets_last_period});
  
  $form->{total_assets_this_period} = $form->format_amount($myconfig, $form->{total_assets_this_period}, $form->{decimalplaces}, "- ");
  
  $form->{total_liabilities_this_period} = $form->format_amount($myconfig, $form->{total_liabilities_this_period}, $form->{decimalplaces}, "- ");
  
  $form->{total_equity_this_period} = $form->format_amount($myconfig, $form->{total_equity_this_period}, $form->{decimalplaces}, "- ");

}


sub get_accounts {
  my ($dbh, $last_period, $fromdate, $todate, $form, $categories, $excludeyearend) = @_;

  my $department_id;
  my $project_id;
  
  ($null, $department_id) = split /--/, $form->{department};
  ($null, $project_id) = split /--/, $form->{projectnumber};

  my $query;
  my $dpt_where;
  my $dpt_join;
  my $project;
  my $where = "1 = 1";
  my $glwhere = "";
  my $subwhere = "";
  my $yearendwhere = "1 = 1";
  my $item;
 
  my $category = "AND (";
  foreach $item (@{ $categories }) {
    $category .= qq|c.category = '$item' OR |;
  }
  $category =~ s/OR $/\)/;


  # get headings
  $query = qq|SELECT accno, description, category
	      FROM chart c
	      WHERE c.charttype = 'H'
	      $category
	      ORDER by c.accno|;

  if ($form->{accounttype} eq 'gifi')
  {
    $query = qq|SELECT g.accno, g.description, c.category
		FROM gifi g
		JOIN chart c ON (c.gifi_accno = g.accno)
		WHERE c.charttype = 'H'
		$category
		ORDER BY g.accno|;
  }

  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);
  
  my @headingaccounts = ();
  while ($ref = $sth->fetchrow_hashref(NAME_lc))
  {
    $form->{$ref->{category}}{$ref->{accno}}{description} = "$ref->{description}";
    $form->{$ref->{category}}{$ref->{accno}}{charttype} = "H";
    $form->{$ref->{category}}{$ref->{accno}}{accno} = $ref->{accno};
    
    push @headingaccounts, $ref->{accno};
  }

  $sth->finish;

  if ($form->{method} eq 'cash' && !$todate) {
    $todate = $form->current_date($myconfig);
  }

  if ($fromdate) {
    if ($form->{method} eq 'cash') {
      $subwhere .= " AND ac.transdate >= '$fromdate'";
      $glwhere = " AND ac.transdate >= '$fromdate'";
    } else {
      $where .= " AND ac.transdate >= '$fromdate'";
    }
  }

  if ($todate) {
    $where .= " AND ac.transdate <= '$todate'";
    $subwhere .= " AND ac.transdate <= '$todate'";
    $yearendwhere = "ac.transdate < '$todate'";
  }

  if ($excludeyearend) {
    $ywhere = " AND ac.trans_id NOT IN
               (SELECT trans_id FROM yearend)";
	       
   if ($todate) {
      $ywhere = " AND ac.trans_id NOT IN
		 (SELECT trans_id FROM yearend
		  WHERE transdate <= '$todate')";
    }
       
    if ($fromdate) {
      $ywhere = " AND ac.trans_id NOT IN
		 (SELECT trans_id FROM yearend
		  WHERE transdate >= '$fromdate')";
      if ($todate) {
	$ywhere = " AND ac.trans_id NOT IN
		   (SELECT trans_id FROM yearend
		    WHERE transdate >= '$fromdate'
		    AND transdate <= '$todate')";
      }
    }
  }

  if ($department_id) {
    $dpt_join = qq|
               JOIN department t ON (a.department_id = t.id)
		  |;
    $dpt_where = qq|
               AND t.id = $department_id
	           |;
  }

  if ($project_id) {
    $project = qq|
                 AND ac.project_id = $project_id
		 |;
  }


  if ($form->{accounttype} eq 'gifi') {
    
    if ($form->{method} eq 'cash') {

	$query = qq|
	
	         SELECT g.accno, sum(ac.amount) AS amount,
		 g.description, c.category
		 FROM acc_trans ac
	         JOIN chart c ON (c.id = ac.chart_id)
	         JOIN ar a ON (a.id = ac.trans_id)
	         JOIN gifi g ON (g.accno = c.gifi_accno)
	         $dpt_join
		 WHERE $where
		 AND a.approved = '1'
		 $ywhere
		 $dpt_where
		 $category
		 AND ac.trans_id IN
		   (
		     SELECT trans_id
		     FROM acc_trans ac
		     JOIN chart c ON (ac.chart_id = c.id)
		     WHERE c.link LIKE '%AR_paid%'
		     AND ac.approved = '1'
		     $subwhere
		   )
		 $project
		 GROUP BY g.accno, g.description, c.category
		 
       UNION ALL
       
		 SELECT '' AS accno, SUM(ac.amount) AS amount,
		 '' AS description, c.category
		 FROM acc_trans ac
	         JOIN chart c ON (c.id = ac.chart_id)
	         JOIN ar a ON (a.id = ac.trans_id)
	         $dpt_join
		 WHERE $where
		 AND ac.approved = '1'
		 $ywhere
		 $dpt_where
		 $category
		 AND c.gifi_accno = ''
		 AND ac.trans_id IN
		   (
		     SELECT ac.trans_id
		     FROM acc_trans ac
		     JOIN chart c ON (ac.chart_id = c.id)
		     WHERE c.link LIKE '%AR_paid%'
		     AND ac.approved = '1'
		     $subwhere
		   )
		 $project
		 GROUP BY c.category

       UNION ALL

       	         SELECT g.accno, sum(ac.amount) AS amount,
		 g.description, c.category
		 FROM acc_trans ac
	         JOIN chart c ON (c.id = ac.chart_id)
	         JOIN ap a ON (a.id = ac.trans_id)
	         JOIN gifi g ON (g.accno = c.gifi_accno)
	         $dpt_join
		 WHERE $where
		 AND a.approved = '1'
		 $ywhere
		 $dpt_where
		 $category
		 AND ac.trans_id IN
		   (
		     SELECT ac.trans_id
		     FROM acc_trans ac
		     JOIN chart c ON (ac.chart_id = c.id)
		     WHERE c.link LIKE '%AP_paid%'
		     AND ac.approved = '1'
		     $subwhere
		   )
		 $project
		 GROUP BY g.accno, g.description, c.category
		 
       UNION ALL
       
		 SELECT '' AS accno, SUM(ac.amount) AS amount,
		 '' AS description, c.category
		 FROM acc_trans ac
	         JOIN chart c ON (c.id = ac.chart_id)
	         JOIN ap a ON (a.id = ac.trans_id)
	         $dpt_join
		 WHERE $where
		 AND a.approved = '1'
		 $ywhere
		 $dpt_where
		 $category
		 AND c.gifi_accno = ''
		 AND ac.trans_id IN
		   (
		     SELECT ac.trans_id
		     FROM acc_trans ac
		     JOIN chart c ON (ac.chart_id = c.id)
		     WHERE c.link LIKE '%AP_paid%'
		     AND ac.approved = '1'
		     $subwhere
		   )
		 $project
		 GROUP BY c.category

       UNION ALL

-- add gl
	
	         SELECT g.accno, sum(ac.amount) AS amount,
		 g.description, c.category
		 FROM acc_trans ac
	         JOIN chart c ON (c.id = ac.chart_id)
	         JOIN gifi g ON (g.accno = c.gifi_accno)
	         JOIN gl a ON (a.id = ac.trans_id)
	         $dpt_join
		 WHERE $where
		 AND a.approved = '1'
		 $ywhere
		 $glwhere
		 $dpt_where
		 $category
		 AND NOT (c.link = 'AR' OR c.link = 'AP')
		 $project
		 GROUP BY g.accno, g.description, c.category
		 
       UNION ALL
       
		 SELECT '' AS accno, SUM(ac.amount) AS amount,
		 '' AS description, c.category
		 FROM acc_trans ac
	         JOIN chart c ON (c.id = ac.chart_id)
	         JOIN gl a ON (a.id = ac.trans_id)
	         $dpt_join
		 WHERE $where
		 AND a.approved = '1'
		 $ywhere
		 $glwhere
		 $dpt_where
		 $category
		 AND c.gifi_accno = ''
		 AND NOT (c.link = 'AR' OR c.link = 'AP')
		 $project
		 GROUP BY c.category
		 |;

      if ($excludeyearend) {

         # this is for the yearend

	 $query .= qq|

       UNION ALL
       
	         SELECT g.accno, sum(ac.amount) AS amount,
		 g.description, c.category
		 FROM yearend y
		 JOIN gl a ON (a.id = y.trans_id)
		 JOIN acc_trans ac ON (ac.trans_id = y.trans_id)
		 JOIN chart c ON (c.id = ac.chart_id)
		 JOIN gifi g ON (g.accno = c.gifi_accno)
	         $dpt_join
		 WHERE $yearendwhere
		 AND c.category = 'Q'
		 $dpt_where
		 $project
		 GROUP BY g.accno, g.description, c.category
		 |;
      }

    } else {

      if ($department_id) {
	$dpt_join = qq|
	      JOIN dpt_trans t ON (t.trans_id = ac.trans_id)
	      |;
	$dpt_where = qq|
               AND t.department_id = $department_id
	      |;
      }

      $query = qq|
      
	      SELECT g.accno, SUM(ac.amount) AS amount,
	      g.description, c.category
	      FROM acc_trans ac
	      JOIN chart c ON (c.id = ac.chart_id)
	      JOIN gifi g ON (c.gifi_accno = g.accno)
	      $dpt_join
	      WHERE $where
	      AND ac.approved = '1'
	      $ywhere
	      $dpt_where
	      $category
	      $project
	      GROUP BY g.accno, g.description, c.category
	      
	   UNION ALL
	   
	      SELECT '' AS accno, SUM(ac.amount) AS amount,
	      '' AS description, c.category
	      FROM acc_trans ac
	      JOIN chart c ON (c.id = ac.chart_id)
	      $dpt_join
	      WHERE $where
	      AND ac.approved = '1'
	      $ywhere
	      $dpt_where
	      $category
	      AND c.gifi_accno = ''
	      $project
	      GROUP BY c.category
	      |;

	if ($excludeyearend) {

	  # this is for the yearend

	  $query .= qq|

       UNION ALL
       
	         SELECT g.accno, sum(ac.amount) AS amount,
		 g.description, c.category
		 FROM yearend y
		 JOIN gl a ON (a.id = y.trans_id)
		 JOIN acc_trans ac ON (ac.trans_id = y.trans_id)
		 JOIN chart c ON (c.id = ac.chart_id)
		 JOIN gifi g ON (g.accno = c.gifi_accno)
	         $dpt_join
		 WHERE $yearendwhere
		 AND c.category = 'Q'
		 $dpt_where
		 $project
		 GROUP BY g.accno, g.description, c.category
	      |;
	}
    }
    
  } else {    # standard account

    if ($form->{method} eq 'cash') {

      $query = qq|
	
	         SELECT c.accno, sum(ac.amount) AS amount,
		 c.description, c.category
		 FROM acc_trans ac
		 JOIN chart c ON (c.id = ac.chart_id)
		 JOIN ar a ON (a.id = ac.trans_id)
		 $dpt_join
		 WHERE $where
		 AND ac.approved = '1'
	         $ywhere
		 $dpt_where
		 $category
		 AND ac.trans_id IN
		   (
		     SELECT ac.trans_id
		     FROM acc_trans ac
		     JOIN chart c ON (ac.chart_id = c.id)
		     WHERE c.link LIKE '%AR_paid%'
		     AND ac.approved = '1'
		     $subwhere
		   )
		     
		 $project
		 GROUP BY c.accno, c.description, c.category
		 
	UNION ALL
	
	         SELECT c.accno, sum(ac.amount) AS amount,
		 c.description, c.category
		 FROM acc_trans ac
		 JOIN chart c ON (c.id = ac.chart_id)
		 JOIN ap a ON (a.id = ac.trans_id)
		 $dpt_join
		 WHERE $where
		 AND a.approved = '1'
	         $ywhere
		 $dpt_where
		 $category
		 AND ac.trans_id IN
		   (
		     SELECT ac.trans_id
		     FROM acc_trans ac
		     JOIN chart c ON (ac.chart_id = c.id)
		     WHERE c.link LIKE '%AP_paid%'
		     AND ac.approved = '1'
		     $subwhere
		   )
		     
		 $project
		 GROUP BY c.accno, c.description, c.category
		 
        UNION ALL

		 SELECT c.accno, sum(ac.amount) AS amount,
		 c.description, c.category
		 FROM acc_trans ac
		 JOIN chart c ON (c.id = ac.chart_id)
		 JOIN gl a ON (a.id = ac.trans_id)
		 $dpt_join
		 WHERE $where
		 AND a.approved = '1'
	         $ywhere
		 $glwhere
		 $dpt_where
		 $category
		 AND NOT (c.link = 'AR' OR c.link = 'AP')
		 $project
		 GROUP BY c.accno, c.description, c.category
		 |;

      if ($excludeyearend) {

        # this is for the yearend
	
	$query .= qq|

       UNION ALL
       
	         SELECT c.accno, sum(ac.amount) AS amount,
		 c.description, c.category
		 FROM yearend y
		 JOIN gl a ON (a.id = y.trans_id)
		 JOIN acc_trans ac ON (ac.trans_id = y.trans_id)
		 JOIN chart c ON (c.id = ac.chart_id)
	         $dpt_join
		 WHERE $yearendwhere
		 AND c.category = 'Q'
		 $dpt_where
		 $project
		 GROUP BY c.accno, c.description, c.category
		 |;
      }

    } else {
     
      if ($department_id) {
	$dpt_join = qq|
	      JOIN dpt_trans t ON (t.trans_id = ac.trans_id)
	      |;
	$dpt_where = qq|
               AND t.department_id = $department_id
	      |;
      }

	
      $query = qq|
      
		 SELECT c.accno, sum(ac.amount) AS amount,
		 c.description, c.category
		 FROM acc_trans ac
		 JOIN chart c ON (c.id = ac.chart_id)
		 $dpt_join
		 WHERE $where
		 AND ac.approved = '1'
	         $ywhere
		 $dpt_where
		 $category
		 $project
		 GROUP BY c.accno, c.description, c.category
		 |;

      if ($excludeyearend) {

        # this is for the yearend
	
	$query .= qq|

       UNION ALL
       
	         SELECT c.accno, sum(ac.amount) AS amount,
		 c.description, c.category
		 FROM yearend y
		 JOIN gl a ON (a.id = y.trans_id)
		 JOIN acc_trans ac ON (ac.trans_id = y.trans_id)
		 JOIN chart c ON (c.id = ac.chart_id)
	         $dpt_join
		 WHERE $yearendwhere
		 AND c.category = 'Q'
		 $dpt_where
		 $project
		 GROUP BY c.accno, c.description, c.category
		 |;
      }
    }
  }

  my @accno;
  my $accno;
  my $ref;
  
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {

    # get last heading account
    @accno = grep { $_ le "$ref->{accno}" } @headingaccounts;
    $accno = pop @accno;
    if ($accno && ($accno ne $ref->{accno}) ) {
      if ($last_period)
      {
	$form->{$ref->{category}}{$accno}{last} += $ref->{amount};
      } else {
	$form->{$ref->{category}}{$accno}{this} += $ref->{amount};
      }
    }
    
    $form->{$ref->{category}}{$ref->{accno}}{accno} = $ref->{accno};
    $form->{$ref->{category}}{$ref->{accno}}{description} = $ref->{description};
    $form->{$ref->{category}}{$ref->{accno}}{charttype} = "A";
    
    if ($last_period) {
      $form->{$ref->{category}}{$ref->{accno}}{last} += $ref->{amount};
    } else {
      $form->{$ref->{category}}{$ref->{accno}}{this} += $ref->{amount};
    }
  }
  $sth->finish;

  
  # remove accounts with zero balance
  foreach $category (@{ $categories }) {
    foreach $accno (keys %{ $form->{$category} }) {
      $form->{$category}{$accno}{last} = $form->round_amount($form->{$category}{$accno}{last}, $form->{decimalplaces});
      $form->{$category}{$accno}{this} = $form->round_amount($form->{$category}{$accno}{this}, $form->{decimalplaces});

      delete $form->{$category}{$accno} if ($form->{$category}{$accno}{this} == 0 && $form->{$category}{$accno}{last} == 0);
    }
  }

}



sub trial_balance {
  my ($self, $myconfig, $form) = @_;

  my $dbh = $form->dbconnect($myconfig);

  my ($query, $sth, $ref);
  my %balance = ();
  my %trb = ();
  my $null;
  my $department_id;
  my $project_id;
  my @headingaccounts = ();
  my $dpt_where;
  my $dpt_join;
  my $project;

  my $where = "ac.approved = '1'";
  my $invwhere = $where;
  
  ($null, $department_id) = split /--/, $form->{department};
  ($null, $project_id) = split /--/, $form->{projectnumber};

  if ($department_id) {
    $dpt_join = qq|
                JOIN dpt_trans t ON (ac.trans_id = t.trans_id)
		  |;
    $dpt_where = qq|
                AND t.department_id = $department_id
		|;
  }
  
  
  if ($project_id) {
    $project = qq|
                AND ac.project_id = $project_id
		|;
  }
  
  ($form->{fromdate}, $form->{todate}) = $form->from_to($form->{year}, $form->{month}, $form->{interval}) if $form->{year} && $form->{month}; 
   
  # get beginning balances
  if ($form->{fromdate}) {

    if ($form->{accounttype} eq 'gifi') {
      
      $query = qq|SELECT g.accno, c.category, SUM(ac.amount) AS amount,
                  g.description, c.contra
		  FROM acc_trans ac
		  JOIN chart c ON (ac.chart_id = c.id)
		  JOIN gifi g ON (c.gifi_accno = g.accno)
		  $dpt_join
		  WHERE ac.transdate < '$form->{fromdate}'
		  AND ac.approved = '1'
		  $dpt_where
		  $project
		  GROUP BY g.accno, c.category, g.description, c.contra
		  |;
   
    } else {
      
      $query = qq|SELECT c.accno, c.category, SUM(ac.amount) AS amount,
                  c.description, c.contra
		  FROM acc_trans ac
		  JOIN chart c ON (ac.chart_id = c.id)
		  $dpt_join
		  WHERE ac.transdate < '$form->{fromdate}'
		  AND ac.approved = '1'
		  $dpt_where
		  $project
		  GROUP BY c.accno, c.category, c.description, c.contra
		  |;
		  
    }

    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
      $ref->{amount} = $form->round_amount($ref->{amount}, $form->{precision});
      $balance{$ref->{accno}} = $ref->{amount};

      if ($form->{all_accounts}) {
	$trb{$ref->{accno}}{description} = $ref->{description};
	$trb{$ref->{accno}}{charttype} = 'A';
	$trb{$ref->{accno}}{category} = $ref->{category};
	$trb{$ref->{accno}}{contra} = $ref->{contra};
      }

    }
    $sth->finish;

  }
  

  # get headings
  $query = qq|SELECT c.accno, c.description, c.category
	      FROM chart c
	      WHERE c.charttype = 'H'
	      ORDER by c.accno|;

  if ($form->{accounttype} eq 'gifi')
  {
    $query = qq|SELECT g.accno, g.description, c.category, c.contra
		FROM gifi g
		JOIN chart c ON (c.gifi_accno = g.accno)
		WHERE c.charttype = 'H'
		ORDER BY g.accno|;
  }

  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);
  
  while ($ref = $sth->fetchrow_hashref(NAME_lc))
  {
    $trb{$ref->{accno}}{description} = $ref->{description};
    $trb{$ref->{accno}}{charttype} = 'H';
    $trb{$ref->{accno}}{category} = $ref->{category};
    $trb{$ref->{accno}}{contra} = $ref->{contra};
   
    push @headingaccounts, $ref->{accno};
  }

  $sth->finish;


  if ($form->{fromdate} || $form->{todate}) {
    if ($form->{fromdate}) {
      $where .= " AND ac.transdate >= '$form->{fromdate}'";
      $invwhere .= " AND a.transdate >= '$form->{fromdate}'";
    }
    if ($form->{todate}) {
      $where .= " AND ac.transdate <= '$form->{todate}'";
      $invwhere .= " AND a.transdate <= '$form->{todate}'";
    }
  }


  if ($form->{accounttype} eq 'gifi') {

    $query = qq|SELECT g.accno, g.description, c.category,
                SUM(ac.amount) AS amount, c.contra
		FROM acc_trans ac
		JOIN chart c ON (c.id = ac.chart_id)
		JOIN gifi g ON (c.gifi_accno = g.accno)
		$dpt_join
		WHERE $where
		$dpt_where
		$project
		GROUP BY g.accno, g.description, c.category, c.contra
		ORDER BY accno|;
    
  } else {

    $query = qq|SELECT c.accno, c.description, c.category,
                SUM(ac.amount) AS amount, c.contra
		FROM acc_trans ac
		JOIN chart c ON (c.id = ac.chart_id)
		$dpt_join
		WHERE $where
		$dpt_where
		$project
		GROUP BY c.accno, c.description, c.category, c.contra
                ORDER BY accno|;

  }

  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  # prepare query for each account
  $query = qq|SELECT (SELECT SUM(ac.amount) * -1
	      FROM acc_trans ac
	      JOIN chart c ON (c.id = ac.chart_id)
	      $dpt_join
	      WHERE $where
	      $dpt_where
	      $project
	      AND ac.amount < 0
	      AND c.accno = ?) AS debit,
	      
	     (SELECT SUM(ac.amount)
	      FROM acc_trans ac
	      JOIN chart c ON (c.id = ac.chart_id)
	      $dpt_join
	      WHERE $where
	      $dpt_where
	      $project
	      AND ac.amount > 0
	      AND c.accno = ?) AS credit
	      |;

  if ($form->{accounttype} eq 'gifi') {

    $query = qq|SELECT (SELECT SUM(ac.amount) * -1
		FROM acc_trans ac
		JOIN chart c ON (c.id = ac.chart_id)
		$dpt_join
		WHERE $where
		$dpt_where
		$project
		AND ac.amount < 0
		AND c.gifi_accno = ?) AS debit,
		
	       (SELECT SUM(ac.amount)
		FROM acc_trans ac
		JOIN chart c ON (c.id = ac.chart_id)
		$dpt_join
		WHERE $where
		$dpt_where
		$project
		AND ac.amount > 0
		AND c.gifi_accno = ?) AS credit|;
  
  }
  
  $drcr = $dbh->prepare($query);

  # calculate debit and credit for the period
  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    $trb{$ref->{accno}}{description} = $ref->{description};
    $trb{$ref->{accno}}{charttype} = 'A';
    $trb{$ref->{accno}}{category} = $ref->{category};
    $trb{$ref->{accno}}{contra} = $ref->{contra};
    $trb{$ref->{accno}}{amount} += $ref->{amount};
  }
  $sth->finish;

  my ($debit, $credit);
  
  foreach my $accno (sort keys %trb) {
    $ref = ();
    
    $ref->{accno} = $accno;
    for (qw(description category contra charttype amount)) { $ref->{$_} = $trb{$accno}{$_} }
    
    $ref->{balance} = $balance{$ref->{accno}};

    if ($trb{$accno}{charttype} eq 'A') {
      if ($project_id) {

        if ($ref->{amount} < 0) {
	  $ref->{debit} = $ref->{amount} * -1;
	} else {
	  $ref->{credit} = $ref->{amount};
	}
	next if $form->round_amount($ref->{amount}, $form->{precision}) == 0;

      } else {
	
	# get DR/CR
	$drcr->execute($ref->{accno}, $ref->{accno});
	
	($debit, $credit) = (0,0);
	while (($debit, $credit) = $drcr->fetchrow_array) {
	  $ref->{debit} += $debit;
	  $ref->{credit} += $credit;
	}
	$drcr->finish;

      }

      $ref->{debit} = $form->round_amount($ref->{debit}, $form->{precision});
      $ref->{credit} = $form->round_amount($ref->{credit}, $form->{precision});
    
      if (!$form->{all_accounts}) {
	next if $form->round_amount($ref->{debit} + $ref->{credit}, $form->{precision}) == 0;
      }
    }

    # add subtotal
    @accno = grep { $_ le "$ref->{accno}" } @headingaccounts;
    $accno = pop @accno;
    if ($accno) {
      $trb{$accno}{debit} += $ref->{debit};
      $trb{$accno}{credit} += $ref->{credit};
    }

    push @{ $form->{TB} }, $ref;
    
  }

  $dbh->disconnect;

  # debits and credits for headings
  foreach $accno (@headingaccounts) {
    foreach $ref (@{ $form->{TB} }) {
      if ($accno eq $ref->{accno}) {
        $ref->{debit} = $trb{$accno}{debit};
        $ref->{credit} = $trb{$accno}{credit};
      }
    }
  }

}


sub aging {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);
  my $invoice = ($form->{arap} eq 'ar') ? 'is' : 'ir';

  my $query;

  my $item;
  my $curr;
  
  my %defaults = $form->get_defaults($dbh, \@{['currencies','company','address','businessnumber','tel','fax']});
  for (keys %defaults) { $form->{$_} = $defaults{$_} }

  ($null, $form->{todate}) = $form->from_to($form->{year}, $form->{month}) if $form->{year} && $form->{month};
  
  if (! $form->{todate}) {
    $form->{todate} = $form->current_date($myconfig);
  }
    
  my $where = "a.approved = '1'";
  my $name;
  my $null;
  my $ref;
  my $transdate = ($form->{overdue}) ? "duedate" : "transdate";

  if ($form->{"$form->{vc}_id"}) {
    $where .= qq| AND ct.id = $form->{"$form->{vc}_id"}|;
  } else {
    if ($form->{$form->{vc}} ne "") {
      $name = $form->like(lc $form->{$form->{vc}});
      $where .= qq| AND lower(ct.name) LIKE '$name'|;
    }
    if ($form->{"$form->{vc}number"} ne "") {
      $name = $form->like(lc $form->{"$form->{vc}number"});
      $where .= qq| AND lower(ct.$form->{vc}number) LIKE '$name'|;
    }
  }

  if ($form->{department}) {
    ($null, $department_id) = split /--/, $form->{department};
    $where .= qq| AND a.department_id = $department_id|;
  }
  
  # select outstanding vendors or customers, depends on $ct
  $query = qq|SELECT DISTINCT ct.id, ct.name, ct.language_code
              FROM $form->{vc} ct
	      JOIN $form->{arap} a ON (a.$form->{vc}_id = ct.id)
	      WHERE $where
              AND a.paid != a.amount
              AND (a.$transdate <= '$form->{todate}')
              ORDER BY ct.name|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror;
  
  my @ot = ();
  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @ot, $ref;
  }
  $sth->finish;

  my $buysell = ($form->{arap} eq 'ar') ? 'buy' : 'sell';
  
  my %interval = ( 'Pg' => {
                        'c0' => "(date '$form->{todate}' - interval '0 days')",
			'c15' => "(date '$form->{todate}' - interval '15 days')",
			'c30' => "(date '$form->{todate}' - interval '30 days')",
			'c45' => "(date '$form->{todate}' - interval '45 days')",
			'c60' => "(date '$form->{todate}' - interval '60 days')",
			'c75' => "(date '$form->{todate}' - interval '75 days')",
			'c90' => "(date '$form->{todate}' - interval '90 days')" },
		  'DB2' => {
		        'c0' => "(date ('$form->{todate}') - 0 days)",
			'c15' => "(date ('$form->{todate}') - 15 days)",
			'c30' => "(date ('$form->{todate}') - 30 days)",
			'c45' => "(date ('$form->{todate}') - 45 days)",
			'c60' => "(date ('$form->{todate}') - 60 days)",
			'c75' => "(date ('$form->{todate}') - 75 days)",
			'c90' => "(date ('$form->{todate}') - 90 days)" }
		);

  $interval{Oracle} = $interval{PgPP} = $interval{Pg};
  
  # for each company that has some stuff outstanding
  $form->{currencies} ||= ":";
  
  $where = qq|
	a.paid != a.amount
	AND a.approved = '1'
	AND c.id = ?
	AND a.curr = ?|;
	
  if ($department_id) {
    $where .= qq| AND a.department_id = $department_id|;
  }

  $query = "";
  my $union = "";

  my %c = (c0 => { flds => '(a.amount - a.paid) AS c0, 0.00 AS c15, 0.00 AS c30, 0.00 AS c45, 0.00 AS c60, 0.00 AS c75, 0.00 AS c90' },
           c15 => { flds => '0.00 AS c0, (a.amount - a.paid) AS c15, 0.00 AS c30, 0.00 AS c45, 0.00 AS c60, 0.00 AS c75, 0.00 AS c90' },
           c30 => { flds => '0.00 AS c0, 0.00 AS c15, (a.amount - a.paid) AS c30, 0.00 AS c45, 0.00 AS c60, 0.00 AS c75, 0.00 AS c90' },
           c45 => { flds => '0.00 AS c0, 0.00 AS c15, 0.00 AS c30, (a.amount - a.paid) AS c45, 0.00 AS c60, 0.00 AS c75, 0.00 AS c90' },
           c60 => { flds => '0.00 AS c0, 0.00 AS c15, 0.00 AS c30, 0.00 AS c45, (a.amount - a.paid) AS c60, 0.00 AS c75, 0.00 AS c90' },
           c75 => { flds => '0.00 AS c0, 0.00 AS c15, 0.00 AS c30, 0.00 AS c45, 0.00 AS c60, (a.amount - a.paid) AS c75, 0.00 AS c90' },
           c90 => { flds => '0.00 AS c0, 0.00 AS c15, 0.00 AS c30, 0.00 AS c45, 0.00 AS c60, 0.00 AS c75, (a.amount - a.paid) AS c90' }
	  );
  
  my @c = ();

  for (qw(c0 c15 c30 c45 c45 c60 c75 c90)) {
    if ($form->{$_}) {
      push @c, $_;
    }
  }

  $item = $#c;
  $c{$c[$item]}{and} = qq|AND a.$transdate < $interval{$myconfig->{dbdriver}}{$c[$item]}|;
  
  $c{$c[0]}{and} = qq|
    	  AND (
		  a.$transdate <= $interval{$myconfig->{dbdriver}}{$c[0]}
		  AND a.$transdate >= $interval{$myconfig->{dbdriver}}{$c[1]}
 	      )|;
 
  for (1 .. $item - 1) {
    $c{$c[$_]}{and} = qq|
    	  AND (
		  a.$transdate < $interval{$myconfig->{dbdriver}}{$c[$_]}
		  AND a.$transdate >= $interval{$myconfig->{dbdriver}}{$c[$_+1]}
 	      )|;
  }

  for (@c) {
    
    $query .= qq|$union
    SELECT c.id AS vc_id, c.$form->{vc}number, c.name,
    ad.address1, ad.address2, ad.city, ad.state, ad.zipcode, ad.country,
    c.contact, c.email,
    c.phone as $form->{vc}phone, c.fax as $form->{vc}fax,
    c.$form->{vc}number, c.taxnumber as $form->{vc}taxnumber,
    a.invnumber, a.transdate, a.till, a.ordnumber, a.ponumber, a.notes,
    $c{$_}{flds},
    a.duedate, a.invoice, a.id, a.curr,
      (SELECT $buysell FROM exchangerate e
       WHERE a.curr = e.curr
       AND e.transdate = a.transdate) AS exchangerate
    FROM $form->{arap} a
    JOIN $form->{vc} c ON (a.$form->{vc}_id = c.id)
    JOIN address ad ON (ad.trans_id = c.id)
    WHERE $where
    $c{$_}{and}
|;

    $union = qq|
    UNION
|;
  }
	  
  $query .= qq|

      ORDER BY vc_id, $transdate, invnumber|;

  $sth = $dbh->prepare($query) || $form->dberror($query);

  my @var;
  
  foreach $curr (split /:/, $form->{currencies}) {
  
    foreach $item (@ot) {

      @var = ();
      for (@c) { push @var, ($item->{id}, $curr) }
      
      $sth->execute(@var);

      while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
	$ref->{module} = ($ref->{invoice}) ? $invoice : $form->{arap};
	$ref->{module} = 'ps' if $ref->{till};
	$ref->{exchangerate} ||= 1;
	$ref->{language_code} = $item->{language_code};
	push @{ $form->{AG} }, $ref;
      }
      $sth->finish;

    }
  }

  # get language
  my $query = qq|SELECT *
                 FROM language
		 ORDER BY 2|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while ($ref = $sth->fetchrow_hashref(NAME_lc)) { 
    push @{ $form->{all_language} }, $ref;
  }
  $sth->finish;

  # disconnect
  $dbh->disconnect;

}


sub get_customer {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query = qq|SELECT name, email, cc, bcc
                 FROM $form->{vc} ct
		 WHERE ct.id = $form->{"$form->{vc}_id"}|;
  ($form->{$form->{vc}}, $form->{email}, $form->{cc}, $form->{bcc}) = $dbh->selectrow_array($query);
  
  $dbh->disconnect;

}


sub get_taxaccounts {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);
  my $ARAP = uc $form->{db};
  
  # get tax accounts
  my $query = qq|SELECT DISTINCT c.accno, c.description
                 FROM chart c
		 JOIN tax t ON (c.id = t.chart_id)
		 WHERE c.link LIKE '%${ARAP}_tax%'
                 ORDER BY c.accno|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror;

  my $ref = ();
  while ($ref = $sth->fetchrow_hashref(NAME_lc) ) {
    push @{ $form->{taxaccounts} }, $ref;
  }
  $sth->finish;

  # get gifi tax accounts
  my $query = qq|SELECT DISTINCT g.accno, g.description
                 FROM gifi g
		 JOIN chart c ON (c.gifi_accno= g.accno)
		 JOIN tax t ON (c.id = t.chart_id)
		 WHERE c.link LIKE '%${ARAP}_tax%'
                 ORDER BY accno|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror;

  while ($ref = $sth->fetchrow_hashref(NAME_lc) ) {
    push @{ $form->{gifi_taxaccounts} }, $ref;
  }
  $sth->finish;

  $dbh->disconnect;

}



sub tax_report {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my ($null, $department_id) = split /--/, $form->{department};
  
  # build WHERE
  my $where = "a.approved = '1'";
  my $cashwhere = "";

  if ($department_id) {
    $where .= qq|
                 AND a.department_id = $department_id
		|;
  }
  
  my $query;
  my $sth;
  my $accno;
  
  if ($form->{accno}) {
    if ($form->{accno} =~ /^gifi_/) {
      ($null, $accno) = split /_/, $form->{accno};
      $accno = qq| AND ch.gifi_accno = '$accno'|;
    } else {
      $accno = $form->{accno};
      $accno = qq| AND ch.accno = '$accno'|;
    }
  }

  my $vc;
  my $ARAP;
  
  if ($form->{db} eq 'ar') {
    $vc = "customer";
    $ARAP = "AR";
  }
  if ($form->{db} eq 'ap') {
    $vc = "vendor";
    $ARAP = "AP";
  }

  my $transdate = "a.transdate";

  ($form->{fromdate}, $form->{todate}) = $form->from_to($form->{year}, $form->{month}, $form->{interval}) if $form->{year} && $form->{month};
  
  # if there are any dates construct a where
  if ($form->{fromdate} || $form->{todate}) {
    if ($form->{fromdate}) {
      $where .= " AND $transdate >= '$form->{fromdate}'";
    }
    if ($form->{todate}) {
      $where .= " AND $transdate <= '$form->{todate}'";
    }
  }


  if ($form->{method} eq 'cash') {
    $transdate = "a.datepaid";

    my $todate = $form->{todate};
    if (! $todate) {
      $todate = $form->current_date($myconfig);
    }
    
    $cashwhere = qq|
		 AND ac.trans_id IN
		   (
		     SELECT trans_id
		     FROM acc_trans
		     JOIN chart ON (chart_id = chart.id)
		     WHERE link LIKE '%${ARAP}_paid%'
		     AND a.approved = '1'
		     AND $transdate <= '$todate'
		     AND a.paid = a.amount
		   )
		  |;

  }

    
  my $ml = ($form->{db} eq 'ar') ? 1 : -1;
  
  my %ordinal = ( 'transdate' => 3,
                  'invnumber' => 4,
		  'name' => 5,
		  "${vc}number" => 6,
		  'description' => 8
		);
  
  my @a = qw(transdate invnumber name);
  my $sortorder = $form->sort_order(\@a, \%ordinal);

  if ($form->{summary}) {
    
    $query = qq|SELECT a.id, a.invoice, $transdate AS transdate,
		a.invnumber, n.name, n.${vc}number, a.netamount,
		a.description,
		sum(ac.amount) * $ml AS tax,
		a.till, n.id AS vc_id
		FROM acc_trans ac
	      JOIN $form->{db} a ON (a.id = ac.trans_id)
	      JOIN chart ch ON (ch.id = ac.chart_id)
	      JOIN $vc n ON (n.id = a.${vc}_id)
		WHERE $where
		$accno
		$cashwhere
	GROUP BY a.id, a.invoice, $transdate, a.invnumber, n.name,
	a.netamount, a.till, n.id, a.description, n.${vc}number
		|;

      if ($form->{fromdate}) {
	# include open transactions from previous period
	if ($cashwhere) {
	  $query .= qq|
              UNION
	      
                SELECT a.id, a.invoice, $transdate AS transdate,
		a.invnumber, n.name, n.${vc}number, a.netamount,
		a.description,
		sum(ac.amount) * $ml AS tax,
		a.till, n.id AS vc_id
		FROM acc_trans ac
	      JOIN $form->{db} a ON (a.id = ac.trans_id)
	      JOIN chart ch ON (ch.id = ac.chart_id)
	      JOIN $vc n ON (n.id = a.${vc}_id)
		WHERE a.datepaid >= '$form->{fromdate}'
		$accno
		$cashwhere
	GROUP BY a.id, a.invoice, $transdate, a.invnumber, n.name,
	a.netamount, a.till, n.id, a.description, n.${vc}number
		|;
	}
      }
 
		
    } else {
      
     $query = qq|SELECT a.id, '0' AS invoice, $transdate AS transdate,
		a.invnumber, n.name, n.${vc}number, a.netamount,
		ac.memo AS description,
		ac.amount * $ml AS tax,
		a.till, n.id AS vc_id
		FROM acc_trans ac
	      JOIN $form->{db} a ON (a.id = ac.trans_id)
	      JOIN chart ch ON (ch.id = ac.chart_id)
	      JOIN $vc n ON (n.id = a.${vc}_id)
		WHERE $where
		$accno
		AND a.invoice = '0'
		AND NOT (ch.link LIKE '%_paid' OR ch.link = '$ARAP')
		$cashwhere
		
	      UNION ALL
	      
		SELECT a.id, '1' AS invoice, $transdate AS transdate,
		a.invnumber, n.name, n.${vc}number,
		i.sellprice * i.qty * $ml AS netamount,
		i.description,
		i.sellprice * i.qty * $ml *
		(SELECT tx.rate FROM tax tx WHERE tx.chart_id = ch.id AND (tx.validto > $transdate OR tx.validto IS NULL) ORDER BY validto LIMIT 1) AS tax,
		a.till, n.id AS vc_id
		FROM acc_trans ac
	      JOIN $form->{db} a ON (a.id = ac.trans_id)
	      JOIN chart ch ON (ch.id = ac.chart_id)
	      JOIN $vc n ON (n.id = a.${vc}_id)
	      JOIN ${vc}tax t ON (t.${vc}_id = n.id AND t.chart_id = ch.id)
	      JOIN invoice i ON (i.trans_id = a.id)
	      JOIN partstax pt ON (pt.parts_id = i.parts_id AND pt.chart_id = ch.id)
		WHERE $where
		$accno
		AND a.invoice = '1'
		$cashwhere
		|;

      if ($form->{fromdate}) {
	if ($cashwhere) {
	 $query .= qq|
	      UNION
	      
	        SELECT a.id, '0' AS invoice, $transdate AS transdate,
		a.invnumber, n.name, n.${vc}number, a.netamount,
		ac.memo AS description,
		ac.amount * $ml AS tax,
		a.till, n.id AS vc_id
		FROM acc_trans ac
	      JOIN $form->{db} a ON (a.id = ac.trans_id)
	      JOIN chart ch ON (ch.id = ac.chart_id)
	      JOIN $vc n ON (n.id = a.${vc}_id)
		WHERE a.datepaid >= '$form->{fromdate}'
		$accno
		AND a.invoice = '0'
		AND NOT (ch.link LIKE '%_paid' OR ch.link = '$ARAP')
		$cashwhere
		
	      UNION
	      
		SELECT a.id, '1' AS invoice, $transdate AS transdate,
		a.invnumber, n.name, n.${vc}number,
		i.sellprice * i.qty * $ml AS netamount,
		i.description,
		i.sellprice * i.qty * $ml *
		(SELECT tx.rate FROM tax tx WHERE tx.chart_id = ch.id AND (tx.validto > $transdate OR tx.validto IS NULL) ORDER BY validto LIMIT 1) AS tax,
		a.till, n.id AS vc_id
		FROM acc_trans ac
	      JOIN $form->{db} a ON (a.id = ac.trans_id)
	      JOIN chart ch ON (ch.id = ac.chart_id)
	      JOIN $vc n ON (n.id = a.${vc}_id)
	      JOIN ${vc}tax t ON (t.${vc}_id = n.id AND t.chart_id = ch.id)
	      JOIN invoice i ON (i.trans_id = a.id)
	      JOIN partstax pt ON (pt.parts_id = i.parts_id AND pt.chart_id = ch.id)
		WHERE a.datepaid >= '$form->{fromdate}'
		$accno
		AND a.invoice = '1'
		$cashwhere
		|;
	}
      }
    }


  if ($form->{report} =~ /nontaxable/) {

    if ($form->{summary}) {
      # only gather up non-taxable transactions
      $query = qq|SELECT DISTINCT a.id, a.invoice, $transdate AS transdate,
		  a.invnumber, n.name, n.${vc}number, a.netamount,
		  a.description,
		  a.till, n.id AS vc_id
		  FROM acc_trans ac
		JOIN $form->{db} a ON (a.id = ac.trans_id)
		JOIN $vc n ON (n.id = a.${vc}_id)
		  WHERE $where
		  AND a.netamount = a.amount
		  $cashwhere
		  |;

      if ($form->{fromdate}) {
	if ($cashwhere) {
	  $query .= qq|
                UNION
		
                  SELECT DISTINCT a.id, a.invoice, $transdate AS transdate,
		  a.invnumber, n.name, n.${vc}number, a.netamount,
		  a.description,
		  a.till, n.id AS vc_id
		  FROM acc_trans ac
		JOIN $form->{db} a ON (a.id = ac.trans_id)
		JOIN $vc n ON (n.id = a.${vc}_id)
		WHERE a.datepaid >= '$form->{fromdate}'
		  AND a.netamount = a.amount
		  $cashwhere
		  |;
	}
      }
		  
    } else {

      # gather up details for non-taxable transactions
      $query = qq|SELECT a.id, '0' AS invoice, $transdate AS transdate,
		  a.invnumber, n.name, n.${vc}number,
		  ac.amount * $ml AS netamount,
		  ac.memo AS description,
		  a.till, n.id AS vc_id
		  FROM acc_trans ac
		JOIN $form->{db} a ON (a.id = ac.trans_id)
		JOIN $vc n ON (n.id = a.${vc}_id)
		JOIN chart ch ON (ch.id = ac.chart_id)
		  WHERE $where
		  AND a.invoice = '0'
		  AND a.netamount = a.amount
		  AND NOT (ch.link LIKE '%_paid' OR ch.link = '$ARAP')
		  $cashwhere
		GROUP BY a.id, $transdate, a.invnumber, n.name, ac.amount,
		ac.memo, a.till, n.id, n.${vc}number
		
		UNION ALL
		
		  SELECT a.id, '1' AS invoice, $transdate AS transdate,
		  a.invnumber, n.name, n.${vc}number,
		  sum(ac.sellprice * ac.qty) * $ml AS netamount,
		  ac.description,
		  a.till, n.id AS vc_id
		  FROM invoice ac
		JOIN $form->{db} a ON (a.id = ac.trans_id)
		JOIN $vc n ON (n.id = a.${vc}_id)
		  WHERE $where
		  AND a.invoice = '1'
		  AND (
		    a.${vc}_id NOT IN (
			  SELECT ${vc}_id FROM ${vc}tax t (${vc}_id)
					 ) OR
		    ac.parts_id NOT IN (
			  SELECT parts_id FROM partstax p (parts_id)
				      )
		      )
		  $cashwhere
		  GROUP BY a.id, a.invnumber, $transdate, n.name,
		  ac.description, a.till, n.id, n.${vc}number
		  |;

      if ($form->{fromdate}) {
	if ($cashwhere) {
	  $query .= qq|
                UNION
		
                  SELECT a.id, '0' AS invoice, $transdate AS transdate,
		  a.invnumber, n.name, n.${vc}number, a.netamount,
		  ac.memo AS description,
		  a.till, n.id AS vc_id
		  FROM acc_trans ac
		JOIN $form->{db} a ON (a.id = ac.trans_id)
		JOIN $vc n ON (n.id = a.${vc}_id)
		JOIN chart ch ON (ch.id = ac.chart_id)
		  WHERE a.datepaid >= '$form->{fromdate}'
		  AND a.invoice = '0'
		  AND a.netamount = a.amount
		  AND NOT (c.link LIKE '%_paid' OR c.link = '$ARAP')
		  $cashwhere
		GROUP BY a.id, $transdate, a.invnumber, n.name, a.netamount,
		ac.memo, a.till, n.id, n.${vc}number
		
		UNION
		
		  SELECT a.id, '1' AS invoice, $transdate AS transdate,
		  a.invnumber, n.name, n.${vc}number,
		  sum(ac.sellprice * ac.qty) * $ml AS netamount,
		  ac.description,
		  a.till, n.id AS vc_id
		  FROM invoice ac
		JOIN $form->{db} a ON (a.id = ac.trans_id)
		JOIN $vc n ON (n.id = a.${vc}_id)
		  WHERE a.datepaid >= '$form->{fromdate}'
		  AND a.invoice = '1'
		  AND (
		    a.${vc}_id NOT IN (
			  SELECT ${vc}_id FROM ${vc}tax t (${vc}_id)
					 ) OR
		    ac.parts_id NOT IN (
			  SELECT parts_id FROM partstax p (parts_id)
				      )
		      )
		  $cashwhere
		  GROUP BY a.id, a.invnumber, $transdate, n.name,
		  ac.description, a.till, n.id, n.${vc}number
		  |;
	}
      }

    }
  }

  
  $query .= qq|
	      ORDER by $sortorder|;

  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while ( my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    $ref->{tax} = $form->round_amount($ref->{tax}, $form->{precision});
    if ($form->{report} =~ /nontaxable/) {
      push @{ $form->{TR} }, $ref if $ref->{netamount};
    } else {
      push @{ $form->{TR} }, $ref if $ref->{tax};
    }
  }

  $sth->finish;
  $dbh->disconnect;

}


sub paymentaccounts {
  my ($self, $myconfig, $form) = @_;
 
  # connect to database, turn AutoCommit off
  my $dbh = $form->dbconnect_noauto($myconfig);

  my $ARAP = uc $form->{db};
  
  # get A(R|P)_paid accounts
  my $query = qq|SELECT accno, description
                 FROM chart
                 WHERE link LIKE '%${ARAP}_paid%'
		 ORDER BY accno|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);
 
  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{PR} }, $ref;
  }
  $sth->finish;

  $form->all_years($myconfig, $dbh);
  
  $dbh->disconnect;

}

 
sub payments {
  my ($self, $myconfig, $form) = @_;

  # connect to database, turn AutoCommit off
  my $dbh = $form->dbconnect_noauto($myconfig);

  my $ml = ($form->{db} eq 'ar') ? -1 : 1;
  my $query;
  my $sth;
  my $dpt_join;
  my $where = "1 = 1";
  my $var;
  my $arapwhere;
  my $gl = ($form->{till} eq "");

  if ($form->{department_id}) {
    $dpt_join = qq|
	         JOIN dpt_trans t ON (t.trans_id = ac.trans_id)
		 |;

    $where .= qq|
		 AND t.department_id = $form->{department_id}
		|;
  }

  ($form->{fromdate}, $form->{todate}) = $form->from_to($form->{year}, $form->{month}, $form->{interval}) if $form->{year} && $form->{month};
  
  if ($form->{fromdate}) {
    $where .= " AND ac.transdate >= '$form->{fromdate}'";
  }
  if ($form->{todate}) {
    $where .= " AND ac.transdate <= '$form->{todate}'";
  }
  if (!$form->{fx_transaction}) {
    $where .= " AND ac.fx_transaction = '0'";
  }
  
  if ($form->{description} ne "") {
    $var = $form->like(lc $form->{description});
    $where .= " AND lower(a.description) LIKE '$var'";
  }
  if ($form->{source} ne "") {
    $var = $form->like(lc $form->{source});
    $where .= " AND lower(ac.source) LIKE '$var'";
  }
  if ($form->{memo} ne "") {
    $var = $form->like(lc $form->{memo});
    $where .= " AND lower(ac.memo) LIKE '$var'";
  }
  if ($form->{"$form->{vc}number"} ne "") {
    $var = $form->like(lc $form->{"$form->{vc}number"});
    $where .= " AND lower(c.$form->{vc}number) LIKE '$var'";
    $gl = 0;
  }
  if ($form->{$form->{vc}} ne "") {
    $var = $form->like(lc $form->{$form->{vc}});
    $where .= " AND lower(c.name) LIKE '$var'";
    $gl = 0;
  }


  my %ordinal = ( 'description' => 1,
                  'name' => 2,
		  'transdate' => 3,
		  'source' => 5,
		  'employee' => 7,
		  'till' => 8,
		  'customernumber' => 14,
		  'vendornumber' => 14,
		  'reference' => 15
		);

  my @a = qw(name transdate employee);
  my $sortorder = $form->sort_order(\@a, \%ordinal);
  
  # cycle through each id
  foreach my $accno (split(/ /, $form->{paymentaccounts})) {

    $query = qq|SELECT id, accno, description
                FROM chart
		WHERE accno = '$accno'|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    my $ref = $sth->fetchrow_hashref(NAME_lc);
    push @{ $form->{PR} }, $ref;
    $sth->finish;

    $query = qq|SELECT a.description, c.name, ac.transdate,
                sum(ac.amount) * $ml AS paid,
                ac.source, ac.memo, e.name AS employee, a.till, a.curr,
		'$form->{db}' AS module, ac.trans_id, c.id AS vcid, a.invoice,
		c.$form->{vc}number, a.invnumber AS reference
		FROM acc_trans ac
	        JOIN $form->{db} a ON (ac.trans_id = a.id)
	        JOIN $form->{vc} c ON (c.id = a.$form->{vc}_id)
		LEFT JOIN employee e ON (a.employee_id = e.id)
	        $dpt_join
		WHERE $where
		AND ac.chart_id = $ref->{id}
		AND ac.approved = '1'|;

    if ($form->{till} ne "") {
      $query .= " AND a.invoice = '1' 
                  AND NOT a.till IS NULL";
      
      if ($myconfig->{role} eq 'user') {
	$query .= " AND e.login = '$form->{login}'";
      }
    }

    $query .= qq|
                GROUP BY a.description, c.name, ac.transdate, ac.source,
		ac.memo, e.name, a.till, a.curr, ac.trans_id, c.id, a.invoice,
		c.$form->{vc}number, a.invnumber
		|;

    if ($gl) {
      # don't need gl for a till or if there is a name
      
      $query .= qq|
 	UNION ALL
		SELECT a.description, '' AS name, ac.transdate,
		sum(ac.amount) * $ml AS paid, ac.source,
		ac.memo, e.name AS employee, '' AS till, '' AS curr,
		'gl' AS module, ac.trans_id, '0' AS vcid, '0' AS invoice,
		'' AS $form->{vc}number, a.reference
		FROM acc_trans ac
	        JOIN gl a ON (a.id = ac.trans_id)
		LEFT JOIN employee e ON (a.employee_id = e.id)
	        $dpt_join
		WHERE $where
		AND ac.chart_id = $ref->{id}
		AND a.approved = '1'
		AND (ac.amount * $ml) > 0
	GROUP BY a.description, ac.transdate, ac.source, ac.memo, e.name,
	        ac.trans_id, a.reference
		|;

    }

    $query .= qq|
                ORDER BY $sortorder|;

    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    while (my $pr = $sth->fetchrow_hashref(NAME_lc)) {
      push @{ $form->{$ref->{id}} }, $pr;
    }
    $sth->finish;

  }
  
  $dbh->disconnect;
  
}


1;


