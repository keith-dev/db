# See the file LICENSE for redistribution information.
#
# Copyright (c) 1996, 1997, 1998, 1999
#	Sleepycat Software.  All rights reserved.
#
#	@(#)test020.tcl	11.5 (Sleepycat) 9/24/99
#
# DB Test 20 {access method}
# Test in-memory databases.
proc test020 { method {nentries 10000} args } {
	source ./include.tcl

	set args [convert_args $method $args]
	set omethod [convert_method $method]
	puts "Test020: $method ($args) $nentries equal key/data pairs"

	# Create the database and open the dictionary
	set t1 $testdir/t1
	set t2 $testdir/t2
	set t3 $testdir/t3
	cleanup $testdir
	set db [eval {berkdb \
	    open -create -truncate -mode 0644} $args {$omethod}]
	error_check_good dbopen [is_valid_db $db] TRUE
	set did [open $dict]

	set pflags ""
	set gflags ""
	set txn ""
	set count 0

	if { [is_record_based $method] == 1 } {
		set checkfunc test020_recno.check
		append gflags " -recno"
	} else {
		set checkfunc test020.check
	}
	puts "\tTest020.a: put/get loop"
	# Here is the loop where we put and get each key/data pair
	while { [gets $did str] != -1 && $count < $nentries } {
		if { [is_record_based $method] == 1 } {
			global kvals

			set key [expr $count + 1]
			set kvals($key) [pad_data $method $str]
		} else {
			set key $str
		}
		set ret [eval {$db put} \
		    $txn $pflags {$key [chop_data $method $str]}]
		error_check_good put $ret 0
		set ret [eval {$db get} $txn $gflags {$key}]
		error_check_good \
		    get $ret [list [list $key [pad_data $method $str]]]
		incr count
	}
	close $did
	# Now we will get each key from the DB and compare the results
	# to the original.
	puts "\tTest020.b: dump file"
	dump_file $db $txn $t1 $checkfunc
	error_check_good db_close [$db close] 0

	# Now compare the keys to see if they match the dictionary (or ints)
	if { [is_record_based $method] == 1 } {
		set oid [open $t2 w]
		for {set i 1} {$i <= $nentries} {set i [incr i]} {
			puts $oid $i
		}
		close $oid
		exec $MV $t1 $t3
	} else {
		set q q
		exec $SED $nentries$q $dict > $t3
		exec $SORT $t3 > $t2
		exec $SORT $t1 > $t3
	}

	error_check_good Test020:diff($t3,$t2) \
	    [catch { exec $CMP $t3 $t2 } res] 0
}

# Check function for test020; keys and data are identical
proc test020.check { key data } {
	error_check_good "key/data mismatch" $data $key
}

proc test020_recno.check { key data } {
	global dict
	global kvals

	error_check_good key"$key"_exists [info exists kvals($key)] 1
	error_check_good "data mismatch: key $key" $data $kvals($key)
}