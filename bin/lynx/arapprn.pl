#=====================================================================
# SQL-Ledger ERP
# Copyright (c) 2006
#
#  Author: DWS Systems Inc.
#     Web: http://www.sql-ledger.com
# 
#======================================================================
#
# printing routines for ar, ap
#

# any custom scripts for this one
if (-f "$form->{path}/custom_arapprn.pl") {
      eval { require "$form->{path}/custom_arapprn.pl"; };
}
if (-f "$form->{path}/$form->{login}_arapprn.pl") {
      eval { require "$form->{path}/$form->{login}_arapprn.pl"; };
}

1;
# end of main


sub print {

  if ($form->{media} !~ /screen/) {
    $form->error($locale->text('Select postscript or PDF!')) if $form->{format} !~ /(postscript|pdf)/;
    $old_form = new Form;
    for (keys %$form) { $old_form->{$_} = $form->{$_} }
  }
 
  if ($form->{formname} =~ /(check|receipt)/) {
    if ($form->{media} eq 'screen') {
      $form->error($locale->text('Select postscript or PDF!')) if $form->{format} !~ /(postscript|pdf)/;
    }
  }

  if (! $form->{invnumber}) {
    $invfld = 'sinumber';
    $invfld = 'vinumber' if $form->{ARAP} eq 'AP';
    if ($form->{media} eq 'screen') {
      $form->{invnumber} = $form->update_defaults(\%myconfig, $invfld);
      if ($form->{media} eq 'screen') {
	&update;
	exit;
      }
    }
  }

  if ($form->{formname} =~ /(check|receipt)/) {
    if ($form->{media} ne 'screen') {
      for (qw(action header)) { delete $form->{$_} }
      $form->{invtotal} = $form->{oldinvtotal};
      
      foreach $key (keys %$form) {
	$form->{$key} =~ s/&/%26/g;
	$form->{previousform} .= qq|$key=$form->{$key}&|;
      }
      chop $form->{previousform};
      $form->{previousform} = $form->escape($form->{previousform}, 1);
    }

    if ($form->{paidaccounts} > 1) {
      if ($form->{"paid_$form->{paidaccounts}"}) {
	&update;
	exit;
      } elsif ($form->{paidaccounts} > 2) {
	&select_payment;
	exit;
      }
    } else {
      $form->error($locale->text('Nothing to print!'));
    }
    
  }

  &{ "print_$form->{formname}" }($old_form, 1);

}


sub print_check {
  my ($old_form, $i) = @_;
  
  $display_form = ($form->{display_form}) ? $form->{display_form} : "display_form";

  if ($form->{"paid_$i"}) {
    @a = ();
    
    if (exists $form->{longformat}) {
      $form->{"datepaid_$i"} = $locale->date(\%myconfig, $form->{"datepaid_$i"}, $form->{longformat});
    }

    push @a, "source_$i", "memo_$i";
    $form->format_string(@a);
  }

  $form->{amount} = $form->{"paid_$i"};

  if (($form->{formname} eq 'check' && $form->{vc} eq 'customer') ||
    ($form->{formname} eq 'receipt' && $form->{vc} eq 'vendor')) {
    $form->{amount} =~ s/-//g;
  }
    
  for (qw(datepaid source memo)) { $form->{$_} = $form->{"${_}_$i"} }

  AA->company_details(\%myconfig, \%$form);
  @a = qw(name address1 address2 city state zipcode country);
  push @a, qw(firstname lastname salutation contacttitle occupation mobile);
 
  foreach $item (qw(invnumber ordnumber)) {
    $temp{$item} = $form->{$item};
    delete $form->{$item};
    push(@{ $form->{$item} }, $temp{$item});
  }
  push(@{ $form->{invdate} }, $form->{transdate});
  push(@{ $form->{due} }, $form->format_amount(\%myconfig, $form->{oldinvtotal}, $form->{precision}));
  push(@{ $form->{paid} }, $form->{"paid_$i"});

  use SL::CP;
  $c = CP->new(($form->{language_code}) ? $form->{language_code} : $myconfig{countrycode}); 
  $c->init;
  ($whole, $form->{decimal}) = split /\./, $form->parse_amount(\%myconfig, $form->{amount});

  $form->{decimal} .= "00";
  $form->{decimal} = substr($form->{decimal}, 0, 2);
  $form->{text_decimal} = $c->num2text($form->{decimal} * 1);
  $form->{text_amount} = $c->num2text($whole);
  $form->{integer_amount} = $whole;

  if ($form->{cd_amount}) {
    ($whole, $form->{cd_decimal}) = split /\./, $form->{cd_invtotal};
    $form->{cd_decimal} .= "00";
    $form->{cd_decimal} = substr($form->{cd_decimal}, 0, 2);
    $form->{text_cd_decimal} = $c->num2text($form->{cd_decimal} * 1);
    $form->{text_cd_invtotal} = $c->num2text($whole);
    $form->{integer_cd_invtotal} = $whole;
  }
  
  push @a, (qw(text_amount text_decimal text_cd_invtotal text_cd_decimal));
  
  ($form->{employee}) = split /--/, $form->{employee};

  $form->{notes} =~ s/^\s+//g;
  
  push @a, qw(notes company address tel fax businessnumber);
  
  $form->format_string(@a);

  $form->{templates} = "$myconfig{templates}";
  $form->{IN} = ($form->{formname} eq 'transaction') ? lc $form->{ARAP} . "_$form->{formname}.html" : "$form->{formname}.html";

  if ($form->{format} =~ /(postscript|pdf)/) {
    $form->{IN} =~ s/html$/tex/;
  }

  if ($form->{media} !~ /(screen)/) {
    $form->{OUT} = "| $printer{$form->{media}}";
    
    if ($form->{printed} !~ /$form->{formname}/) {

      $form->{printed} .= " $form->{formname}";
      $form->{printed} =~ s/^ //;

      $form->update_status(\%myconfig);
    }

    %audittrail = ( tablename   => lc $form->{ARAP},
                    reference   => $form->{invnumber},
		    formname    => $form->{formname},
		    action      => 'printed',
		    id          => $form->{id} );
    
    %status = ();
    for (qw(printed audittrail)) { $status{$_} = $form->{$_} }
    
    $status{audittrail} .= $form->audittrail("", \%myconfig, \%audittrail);

  }

  $form->{fileid} = $invnumber;
  $form->{fileid} =~ s/(\s|\W)+//g;

  $form->parse_template(\%myconfig, $userspath);

  if ($form->{previousform}) {
  
    $previousform = $form->unescape($form->{previousform});

    for (keys %$form) { delete $form->{$_} }

    foreach $item (split /&/, $previousform) {
      ($key, $value) = split /=/, $item, 2;
      $value =~ s/%26/&/g;
      $form->{$key} = $value;
    }

    for (qw(exchangerate creditlimit creditremaining)) { $form->{$_} = $form->parse_amount(\%myconfig, $form->{$_}) }

    for (1 .. $form->{rowcount}) { $form->{"amount_$_"} = $form->parse_amount(\%myconfig, $form->{"amount_$_"}) }
    for (split / /, $form->{taxaccounts}) { $form->{"tax_$_"} = $form->parse_amount(\%myconfig, $form->{"tax_$_"}) }

    for $i (1 .. $form->{paidaccounts}) {
      for (qw(paid exchangerate)) { $form->{"${_}_$i"} = $form->parse_amount(\%myconfig, $form->{"${_}_$i"}) }
    }

    for (qw(printed audittrail)) { $form->{$_} = $status{$_} }

    &{ "$display_form" };
    
  }

}


sub print_receipt {
  my ($old_form, $i) = @_;
  
  &print_check($old_form, $i);

}


sub print_transaction {
  my ($old_form) = @_;
 
  $display_form = ($form->{display_form}) ? $form->{display_form} : "display_form";
 
  AA->company_details(\%myconfig, \%$form);

  @a = qw(name address1 address2 city state zipcode country);
  
  $form->{invtotal} = 0;
  foreach $i (1 .. $form->{rowcount} - 1) {
    ($form->{tempaccno}, $form->{tempaccount}) = split /--/, $form->{"$form->{ARAP}_amount_$i"};
    ($form->{tempprojectnumber}) = split /--/, $form->{"projectnumber_$i"};
    $form->{tempdescription} = $form->{"description_$i"};
    
    $form->format_string(qw(tempaccno tempaccount tempprojectnumber tempdescription));
    
    push(@{ $form->{accno} }, $form->{tempaccno});
    push(@{ $form->{account} }, $form->{tempaccount});
    push(@{ $form->{description} }, $form->{tempdescription});
    push(@{ $form->{projectnumber} }, $form->{tempprojectnumber});

    push(@{ $form->{amount} }, $form->{"amount_$i"});

    $form->{subtotal} += $form->parse_amount(\%myconfig, $form->{"amount_$i"});
    
  }

  $form->{cd_subtotal} = $form->{subtotal};
  $cashdiscount = $form->parse_amount($myconfig, $form->{cashdiscount})/100;
  $form->{cd_available} = $form->{subtotal} * $cashdiscount;
  $cdt = $form->parse_amount($myconfig, $form->{discount_paid});
  $cdt ||= $form->{cd_available};
  $form->{cd_subtotal} -= $cdt;
  $form->{cd_amount} = $cdt;

  $cashdiscount = 0;
  if ($form->{subtotal}) {
    $cashdiscount = $cdt / $form->{subtotal};
  }

  $cd_tax = 0;
  for (split / /, $form->{taxaccounts}) {
    
    if ($form->{"tax_$_"}) {
      
      $form->format_string("${_}_description");

      $tax += $amount = $form->parse_amount(\%myconfig, $form->{"tax_$_"});

      $form->{"${_}_tax"} = $form->{"tax_$_"};
      push(@{ $form->{tax} }, $form->{"tax_$_"});

      if ($form->{cdt}) {
	$cdt = ($form->{discount_paid}) ? $form->{"tax_$_"} : $amount * (1 - $cashdiscount);
	$cd_tax += $form->round_amount($cdt, $form->{precision});
	push(@{ $form->{cd_tax} }, $form->format_amount(\%myconfig, $cdt, $form->{precision}));
      } else {
	push(@{ $form->{cd_tax} }, $form->{"tax_$_"});
      }
      
      push(@{ $form->{taxdescription} }, $form->{"${_}_description"});

      $form->{"${_}_taxrate"} = $form->format_amount($myconfig, $form->{"${_}_rate"} * 100);

      push(@{ $form->{taxrate} }, $form->{"${_}_taxrate"});
      
      push(@{ $form->{taxnumber} }, $form->{"${_}_taxnumber"});
    }
  }


  push @a, $form->{ARAP};
  $form->format_string(@a);

  $form->{paid} = 0;
  for $i (1 .. $form->{paidaccounts} - 1) {

    if ($form->{"paid_$i"}) {
    @a = ();
    $form->{paid} += $form->parse_amount(\%myconfig, $form->{"paid_$i"});
    
    if (exists $form->{longformat}) {
      $form->{"datepaid_$i"} = $locale->date(\%myconfig, $form->{"datepaid_$i"}, $form->{longformat});
    }

    push @a, "$form->{ARAP}_paid_$i", "source_$i", "memo_$i";
    $form->format_string(@a);
    
    ($accno, $account) = split /--/, $form->{"$form->{ARAP}_paid_$i"};
    
    push(@{ $form->{payment} }, $form->{"paid_$i"});
    push(@{ $form->{paymentdate} }, $form->{"datepaid_$i"});
    push(@{ $form->{paymentaccount} }, $account);
    push(@{ $form->{paymentsource} }, $form->{"source_$i"});
    push(@{ $form->{paymentmemo} }, $form->{"memo_$i"});
    }
    
  }

  if ($form->{taxincluded}) {
    $tax = 0;
    $cd_tax = 0;
  }

  $form->{invtotal} = $form->{subtotal} + $tax;
  $form->{cd_invtotal} = $form->{cd_subtotal} + $cd_tax;
  $form->{total} = $form->{invtotal} - $form->{paid};

  
  use SL::CP;
  $c = CP->new(($form->{language_code}) ? $form->{language_code} : $myconfig{countrycode}); 
  $c->init;
  ($whole, $form->{decimal}) = split /\./, $form->{invtotal};

  $form->{decimal} .= "00";
  $form->{decimal} = substr($form->{decimal}, 0, 2);
  $form->{text_decimal} = $c->num2text($form->{decimal} * 1); 
  $form->{text_amount} = $c->num2text($whole);
  $form->{integer_amount} = $whole;
  
  for (qw(cd_subtotal cd_amount cd_invtotal invtotal subtotal paid total)) { $form->{$_} = $form->format_amount(\%myconfig, $form->{$_}, $form->{precision}) }
  
  ($form->{employee}) = split /--/, $form->{employee};

  $form->{fdm} = $form->dayofmonth($myconfig{dateformat}, $form->{transdate}, 'fdm');
  $form->{ldm} = $form->dayofmonth($myconfig{dateformat}, $form->{transdate});
  $transdate = $form->datetonum(\%myconfig, $form->{transdate});
  ($form->{yyyy}, $form->{mm}, $form->{dd}) = $transdate =~ /(....)(..)(..)/;
  
  if (exists $form->{longformat}) {
    for (qw(duedate transdate)) { $form->{$_} = $locale->date(\%myconfig, $form->{$_}, $form->{longformat}) }
  }

  # before we format replace <%var%>
  for ("description", "notes", "intnotes") { $form->{$_} =~ s/<%(.*?)%>/$fld = lc $1; $form->{$fld}/ge }
  
  $form->{notes} =~ s/^\s+//g;
  
  @a = ("invnumber", "transdate", "duedate", "notes");

  push @a, qw(company address tel fax businessnumber text_amount text_decimal);
  
  $form->format_string(@a);

  $form->{invdate} = $form->{transdate};

  $form->{templates} = "$myconfig{templates}";
  $form->{IN} = ($form->{formname} eq 'transaction') ? lc $form->{ARAP} . "_$form->{formname}.html" : "$form->{formname}.html";

  if ($form->{format} =~ /(postscript|pdf)/) {
    $form->{IN} =~ s/html$/tex/;
  }

  if ($form->{media} !~ /(screen)/) {
    $form->{OUT} = "| $printer{$form->{media}}";
    
    if ($form->{printed} !~ /$form->{formname}/) {

      $form->{printed} .= " $form->{formname}";
      $form->{printed} =~ s/^ //;

      $form->update_status(\%myconfig);
    }

    $old_form->{printed} = $form->{printed} if %$old_form;
    
    %audittrail = ( tablename   => lc $form->{ARAP},
                    reference   => $form->{"invnumber"},
		    formname    => $form->{formname},
		    action      => 'printed',
		    id          => $form->{id} );
    
    $old_form->{audittrail} .= $form->audittrail("", \%myconfig, \%audittrail) if %$old_form;

  }

  $form->{fileid} = $form->{invnumber};
  $form->{fileid} =~ s/(\s|\W)+//g;

  $form->parse_template(\%myconfig, $userspath);

  if (%$old_form) {
    $old_form->{invnumber} = $form->{invnumber};
    $old_form->{invtotal} = $form->{invtotal};

    for (keys %$form) { delete $form->{$_} }
    for (keys %$old_form) { $form->{$_} = $old_form->{$_} }

    if (! $form->{printandpost}) {
      for (qw(exchangerate creditlimit creditremaining)) { $form->{$_} = $form->parse_amount(\%myconfig, $form->{$_}) }

      for (1 .. $form->{rowcount}) { $form->{"amount_$_"} = $form->parse_amount(\%myconfig, $form->{"amount_$_"}) }
      for (split / /, $form->{taxaccounts}) { $form->{"tax_$_"} = $form->parse_amount(\%myconfig, $form->{"tax_$_"}) }

      for $i (1 .. $form->{paidaccounts}) {
	for (qw(paid exchangerate)) { $form->{"${_}_$i"} = $form->parse_amount(\%myconfig, $form->{"${_}_$i"}) }
      }
    }
    
    &{ "$display_form" };

  }

}


sub print_credit_note { &print_transaction };
sub print_debit_note { &print_transaction };


sub select_payment {

  @column_index = qw(ndx datepaid source memo paid);
  push @column_index, "$form->{ARAP}_paid";

  # list payments with radio button on a form
  $form->header;

  $title = $locale->text('Select payment');

  $column_data{ndx} = qq|<th width=1%>&nbsp;</th>|;
  $column_data{datepaid} = qq|<th>|.$locale->text('Date').qq|</th>|;
  $column_data{source} = qq|<th>|.$locale->text('Source').qq|</th>|;
  $column_data{memo} = qq|<th>|.$locale->text('Memo').qq|</th>|;
  $column_data{paid} = qq|<th>|.$locale->text('Amount').qq|</th>|;
  $column_data{"$form->{ARAP}_paid"} = qq|<th>|.$locale->text('Account').qq|</th>|;

  print qq|
<body>

<form method=post action=$form->{script}>

<table width=100%>
  <tr>
    <th class=listtop>$title</th>
  </tr>
  <tr space=5></tr>
  <tr>
    <td>
      <table width=100%>
	<tr class=listheading>|;

  for (@column_index) { print "\n$column_data{$_}" }
  
  print qq|
	</tr>
|;

  $checked = "checked";
  foreach $i (1 .. $form->{paidaccounts} - 1) {

    for (@column_index) { $column_data{$_} = qq|<td>$form->{"${_}_$i"}</td>| }

    $paid = $form->{"paid_$i"};
    $ok = 1;

    $column_data{ndx} = qq|<td><input name=ndx class=radio type=radio value=$i $checked></td>|;
    $column_data{paid} = qq|<td align=right>$paid</td>|;
    $column_data{datepaid} = qq|<td nowrap>$form->{"datepaid_$i"}</td>|;

    $checked = "";
    
    $j++; $j %= 2;
    print qq|
	<tr class=listrow$j>|;

    for (@column_index) { print "\n$column_data{$_}" }

    print qq|
	</tr>
|;

  }
  
  print qq|
      </table>
    </td>
  </tr>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>
</table>
|;

  for (qw(action nextsub)) { delete $form->{$_} }

  $form->hide_form;
  
  print qq|

<br>
<input type=hidden name=nextsub value=payment_selected>
|;

  if ($ok) {
    print qq|
<input class=submit type=submit name=action value="|.$locale->text('Continue').qq|">|;
  }

  print qq|
</form>

</body>
</html>
|;
  
}

sub payment_selected {

  &{ "print_$form->{formname}" }($form->{oldform}, $form->{ndx});

}


sub print_options {

  if ($form->{selectlanguage}) {
    $lang = qq|<select name=language_code>|.$form->select_option($form->{selectlanguage}, $form->{language_code}, undef, 1).qq|</select>|;
  }
  
  $type = qq|<select name=formname>|.$form->select_option($form->{selectformname}, $form->{formname}, undef, 1).qq|</select>|;

  $media = qq|<select name=media>
          <option value="screen">|.$locale->text('Screen');

  $selectformat = qq|<option value="html">html|;
  
  if (%printer && $latex) {
    for (sort keys %printer) { $media .= qq| 
          <option value="$_">$_| }
  }

  if ($latex) {
    $selectformat .= qq|
<option value="postscript">|.$locale->text('Postscript').qq|
<option value="pdf">|.$locale->text('PDF');
  }

  $format = qq|<select name=format>$selectformat</select>|;
  $format =~ s/(<option value="\Q$form->{format}\E")/$1 selected/;

  $media .= qq|</select>|;
  $media =~ s/(<option value="\Q$form->{media}\E")/$1 selected/;

  print qq|
  <table width=100%>
    <tr>
      <td>$type</td>
      <td>$lang</td>
      <td>$format</td>
      <td>$media</td>
|;

###############
  # remittance voucher
#  $form->{remittancevoucher} = ($form->{remittancevoucher}) ? "checked" : "";
#  $rvp = qq|<select name=rvp>
#	  <option value="\n">|.$locale->text('Screen');
 
#  if (%printer) {
#    for (sort keys %printer) { $rvp .= qq|
#      <option value="$_">$_| }
#  }
  
#  $rvp .= qq|</select>|;

  # set option selected
#  $rvp =~ s/(<option value="\Q$form->{rvp}\E")/$1 selected/;

#  print qq|
#    <td nowrap><input name=remittancevoucher type=checkbox class=checkbox value=1 $form->{remittancevoucher}>|.$locale->text('Remittance Voucher').qq|</td>
#    <td>$rvp</td>
#|;
#################
  
  %status = ( printed => 'Printed',
	      recurring => 'Scheduled' );
  
  print qq|<td align=right width=90%>|;

  for (qw(printed emailed queued recurring)) {
    if ($form->{$_} =~ /$form->{formname}/) {
      print $locale->text($status{$_}).qq|<br>|;
    }
  }
  
  print qq|
      </td>
    </tr>
  </table>
|;

}


sub print_and_post {

  $form->error($locale->text('Select postscript or PDF!')) if $form->{format} !~ /(postscript|pdf)/;
  $form->error($locale->text('Select a Printer!')) if $form->{media} eq 'screen';

  $form->{printandpost} = 1;
  $form->{display_form} = "post";
  &print;

}


