#!/usr/bin/perl

$DATA_WIDTH = 4;
$CRC_WIDTH = 5;
$GENERATOR = 5;

$DATA_WIDTH_DEC = $DATA_WIDTH - 1;
$CRC_WIDTH_DEC = $CRC_WIDTH - 1;
sub crcSerial { 
#in: @crc_serial_array_in, $crc_serial_data_in
#out:@crc_serial_array_out
    $generator_temp = $GENERATOR;
    @crc_buffer_int;
    for (my $i = 0; $i<$CRC_WIDTH; $i += 1) {
	if($i==0) {
	    $crc_buffer_int[0] = $crc_serial_array_in[$CRC_WIDTH-1] ^ $crc_serial_data_in;
	} else {
	    if ($generator_temp%2==1) {
		$crc_buffer_int[$i] = $crc_serial_array_in[$i-1] ^ $crc_serial_array_in[$CRC_WIDTH-1] ^ $crc_serial_data_in;
	    } else {
		$crc_buffer_int[$i] = $crc_serial_array_in[$i-1];
	    }
	}
	$generator_temp = $generator_temp/2;
    }
    @crc_serial_array_out = @crc_buffer_int;
}

sub crcParallel {
#in: @crc_parallel_array_in, @crc_parallel_data_vect_in
#out:@crc_parallel_array_out
    @crc_parallel_array_out = @crc_parallel_array_in;    
    for (my $i = 0; $i<$DATA_WIDTH; $i += 1) {
	@crc_serial_array_in = @crc_parallel_array_out;
	$crc_serial_data_in = $crc_parallel_data_vect_in[$DATA_WIDTH-1-$i];
	&crcSerial();
	@crc_parallel_array_out = @crc_serial_array_out;
    }
}

sub crc_calc_h1_matrix {
    #out: @h1_mat_out
    for (my $i = 0; $i<$DATA_WIDTH; $i += 1) {
	for (my $j = 0; $j<$DATA_WIDTH; $j += 1) {
	    if ($i==$j) {
		$h1_data_vect[$j]=1;
	    }else{
		$h1_data_vect[$j]=0;
	    }
	}
	for (my $j = 0; $j<$CRC_WIDTH; $j += 1) {
	    $h1_buffer_array[$j] = 0;
	}
	@crc_parallel_array_in = @h1_buffer_array;
	@crc_parallel_data_vect_in = @h1_data_vect;
	&crcParallel();
	for (my $j = 0; $j<$CRC_WIDTH; $j += 1) {   
	    $h1_mat_out[$j]->[$i] = $crc_parallel_array_out[$j];
	}
    }
}

sub crc_calc_h2_matrix {
    #out: h2_mat_out
    for (my $i = 0; $i<$DATA_WIDTH; $i += 1) {
	$h2_data_vect[$i] = 0;
    }
    for (my $i = 0; $i<$CRC_WIDTH; $i += 1) {
	for (my $j = 0; $j<$CRC_WIDTH; $j += 1) {
	    if ($i==$j) {
		$h2_buffer_array[$j]=1;
	    }else{
		$h2_buffer_array[$j]=0;
	    }
	}   
	@crc_parallel_array_in = @h2_buffer_array;
	@crc_parallel_data_vect_in = @h2_data_vect;
	&crcParallel();
	for (my $j = 0; $j<$CRC_WIDTH; $j += 1) {   
	    $h2_mat_out[$j]->[$i] = $crc_parallel_array_out[$j];
	}
    }
}

sub print_header {
    print FILE "This file was automatically generated\n\n";
    print FILE "module parallel_crc (\n";
    print FILE "\tinput logic clk, reset_n,\n";
    print FILE "\tinput logic [$DATA_WIDTH_DEC:0] data_in,\n";
    print FILE "\toutput logic [$CRC_WIDTH_DEC:0] crc_out\n";
    print FILE "\t);\n\n";
    print FILE "\tlogic [CRC_WIDTH_DEC:0] lfsr_reg, lfsr_next;\n\n";
    print FILE "\t//registers\n";
    print FILE "\talways_ff @(posedge clk, negedge reset_n) begin\n";
    print FILE "\t\tif (reset_n==1'b0) begin\n";
    print FILE "\t\t\tlfsr_reg <= '0;\n";
    print FILE "\t\tend else begin\n";
    print FILE "\t\t\tlfsr_reg <= lfsr_next;\n";
    print FILE "\t\tend\n";
    print FILE "\tend\n\n";
    print FILE "\t//next state logic\n";
    print FILE "\talways_comb begin\n";
}

sub print_logic {
    for (my $i = 0; $i<$CRC_WIDTH; $i += 1) { 
	$first_done = 0;
	print FILE "\t\tlfsr_next[$i] =";
	for (my $j = 0; $j<$CRC_WIDTH; $j += 1) { 
	    if ($h2_mat_out[$i]->[$j]==1) {
		if ($first_done==0) {
		    print FILE " lfsr_reg[$j]";
		    $first_done = 1;
		}else{
		    print FILE " ^ lfsr_reg[$j]";
		}
	    }
	}
	for (my $j = 0; $j<$DATA_WIDTH; $j += 1) { 
	    if ($h1_mat_out[$i]->[$j]==1) {
		if ($first_done==0) {
		    print FILE " data_in[$j]";
		    $first_done = 1;
		}else{
		    print FILE " ^ data_in[$j]";
		}   
	    }
	}
	print FILE ";\n";
    } 
}

sub print_footer {
    print FILE "\tend\n\n";
    print FILE "\t//output logic\n";
    print FILE "\tassign crc_out = lfsr_reg;\n\n";
    print FILE "endmodule\n";
}

&crc_calc_h1_matrix();
&crc_calc_h2_matrix();

$filename = "parallel_crc.sv";
open(FILE,'>'.$filename) || die "Can not open file $filename: $!";
&print_header;
&print_logic;
&print_footer;

close FILE;
