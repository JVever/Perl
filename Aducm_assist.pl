#!/usr/bin/perl -w
use Tk;
use strict;
              
my $mw = MainWindow->new;

my $label_msg;
my $entry0;
my $entry1;
my $Go; 
my $original_file_name = "no";
my $new_class_name;
my $change_name_sign = 0;
my $source_name;

$mw->title("Testbench Transformation Assistant");

$mw->Label(-relief => 'groove',-text => "Source file name:", -width => 20)->grid($entry0 = $mw->Entry(-relief => 'sunken', -width => 30,
-textvariable => \$source_name),
$mw->Label(-text => '.sv', -width => '5'),-sticky => 'w');
$entry0->insert ('end', 'source.sv'); # put some text in the entry

$mw->Label(-relief => 'groove',-text => "new class name:", -width => 20)->grid($entry1 = $mw->Entry(-relief => 'sunken', -width => 30,
-textvariable => \$new_class_name),
$mw->Label(-text => '.sv', -width => '5'), -sticky => 'w');
$entry1->insert ('end', ''); # put some text in the entry

#first script 
$mw->Checkbutton(-text => "Change Class Name", -variable => \$change_name_sign, -command => \&change_state)->grid("-", "-", -sticky => 'w');

$mw->Label(-relief => 'groove',-text => "original class name:", -width => 20)->grid($entry0 = $mw->Entry(-relief => 'sunken', -width => 30,
-textvariable => \$original_file_name, -state => 'disabled'),
$mw->Label(-text => '.sv', -width => '5'),-sticky => 'w');
$entry0->insert ('end', 'BaseClass'); # put some text in the entry

sub change_state
{
    if($change_name_sign)
    {
        $entry0->configure(-state => 'normal');
    }
    else
    {
        $entry0->configure(-state => 'disabled');
    }
}

my $add_ifndef = 1;
$mw->Checkbutton(-text => "Add `ifndef/endif (same with new class's name)", -variable => \$add_ifndef)->grid("-", "-", -sticky => 'w');

my $add_include = 0;
$mw->Checkbutton(-text => "Add `include & import", -variable => \$add_include)->grid("-", "-", -sticky => 'w');


my $modify_new = 0;
$mw->Checkbutton(-text => "Modify new()", -variable => \$modify_new)->grid("-", "-", -sticky => 'w');

my $add_utils = 0;
$mw->Checkbutton(-text => "Add uvm_component_utils", -variable => \$add_utils)->grid("-", "-", -sticky => 'w');

my $build_phase;
$mw->Checkbutton(-text => "Add main & build_phase", -variable => \$build_phase)->grid("-", "-", -sticky => 'w');


$Go = $mw->Button(-text => "Go", -command => \&START)->grid("-", "-", -sticky => 'nsew');
&bind_message($Go, "Press to start");

#exit button and hint
$b = $mw->Button(-text => "Exit", -command => \&exit)->grid($mw->Label(-textvariable => \$label_msg), -sticky => 'nsew');
&bind_message($b, "Press to quit!");


sub bind_message {
my ($widget, $msg) = @_;
$widget->bind('<Enter>', [ sub { $label_msg = $msg; }  ]);
$widget->bind('<Leave>', sub { $label_msg = "";});
}

MainLoop;

sub START
{
    if(!open SOURCE, $source_name)
    {
        die "failed to open original class file";
    }
    
    my $temp;
    my @list;
           #open a new file named with the new class name and save the code in it
#    open DEST, "> $new_class_name.sv";
    open DEST, "> destination.sv";
    print "old_name:".$original_file_name."   new_name:".$new_class_name."\n";      
    while(<SOURCE>)
    {
        $temp = $_;    
        
        #change the class name
        if($change_name_sign)
        {
             $temp =~ s%(.*)(\b$original_file_name\b)(.*)%//J \n$1$new_class_name$3%g;
        }
         
        $temp =~ s%(.*\bclass ).*%//J \n$1$new_class_name extends ;%;
         
        #add parent to new
        if($modify_new)
        {
            $temp =~ s%(.*\bfunction.*new)(.*)%//J \n$1(string name, uvm_component parent);\n//$2%g;
            $temp =~ s%super\.new.*%//J \n\t\tsuper.new(name, parent);%g;
            $temp =~ s%protected string.*%%g;
            $temp =~ s%this\.name =.*%//J \n\t\tsuper.new(name, parent);%g;
        }

        #add uvm_comonent_utils after  class ***;
        if($add_utils)
        {
            if($build_phase)
            {

                #delete extern task main()
#                $temp =~ s%(extern .*task main\(\));%//J delete main%;
                $temp =~ s%(\bclass \b.*;)%$1\n//J \n\t`uvm_component_utils($new_class_name)\n
\textern virtual function void build_phase(uvm_phase phase);
\textern virtual task main_phase(uvm_phase phase);\n%g;

                #add main_phase
                $temp =~ s%(.*task.*\:\:main\(.*)%$1\n//J \ntask $new_class_name\:\:main_phase(uvm_phase phase);\n\tsuper.main_phase(phase);\n%g;
                $temp =~ s%(endtask.*main)%$1\n//J \nendtask: main_phase\n%;
            }
            else
            {
                $temp =~ s%(\bclass \b.*;)%$1\n//J \n\t`uvm_component_utils($new_class_name)\n%g;
            }
        }

        if($build_phase)
        {
            $temp =~ s%endclass.*%//J \nendclass:$new_class_name\n//J \nfunction void $new_class_name\:\:build_phase(uvm_phase phase);\n\tsuper.build_phase(phase);\n\nendfunction: build_phase\n\n//J \ntask $new_class_name\:\:main_phase(uvm_phase phase);\n\tsuper.main_phase(phase);\n\nendtask\n\n%g;
        }
        else
        {
            $temp =~ s%endclass.*%//J \nendclass: $new_class_name\n%g;
        }
        push @list, $temp;
    }

    #add ifndef at the top and bottom of file
    if($add_ifndef)
    {
        my $ifndef;
        my $define;
        $ifndef = "//J \n`ifndef $new_class_name"."__sv\n";
        $define = "`define "."$new_class_name"."__sv\n";
        print DEST $ifndef;
        print DEST $define; 
    }

    if($add_include)
    {
        print DEST "\n\`include \"uvm_macros.svh\"\nimport uvm_pkg\:\:\*\;\n";
    }

    #print the other part of code
    while(@list)
    {
        $temp = shift @list;
        print DEST $temp;
    }

     if($add_ifndef)
    {
        my $endif;
        $endif = "\n\n//J \n`endif\n\n";
        print DEST $endif; 
    }
           
    close SOURCE;
    close DEST;

    $mw->messageBox(-message => "Transformation Finished", -type => "ok");
}
