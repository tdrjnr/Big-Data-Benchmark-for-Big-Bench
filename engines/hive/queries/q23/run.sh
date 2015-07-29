#!/usr/bin/env bash

#"INTEL CONFIDENTIAL"
#Copyright 2015  Intel Corporation All Rights Reserved. 
#
#The source code contained or described herein and all documents related to the source code ("Material") are owned by Intel Corporation or its suppliers or licensors. Title to the Material remains with Intel Corporation or its suppliers and licensors. The Material contains trade secrets and proprietary and confidential information of Intel or its suppliers and licensors. The Material is protected by worldwide copyright and trade secret laws and treaty provisions. No part of the Material may be used, copied, reproduced, modified, published, uploaded, posted, transmitted, distributed, or disclosed in any way without Intel's prior express written permission.
#
#No license under any patent, copyright, trade secret or other intellectual property right is granted to or conferred upon you by disclosure or delivery of the Materials, either expressly, by implication, inducement, estoppel or otherwise. Any license under such intellectual property rights must be express and approved by Intel in writing.

RESULT_TABLE1="${RESULT_TABLE}1"
RESULT_DIR1="$RESULT_DIR/$RESULT_TABLE1"
RESULT_TABLE2="${RESULT_TABLE}2"
RESULT_DIR2="$RESULT_DIR/$RESULT_TABLE2"

BINARY_PARAMS="$BINARY_PARAMS --hiveconf RESULT_TABLE1=$RESULT_TABLE1 --hiveconf RESULT_DIR1=$RESULT_DIR1 --hiveconf RESULT_TABLE2=$RESULT_TABLE2 --hiveconf RESULT_DIR2=$RESULT_DIR2"


query_run_main_method () {
	QUERY_SCRIPT="$QUERY_DIR/$QUERY_NAME.sql"
	if [ ! -r "$QUERY_SCRIPT" ]
	then
		echo "SQL file $QUERY_SCRIPT can not be read."
		exit 1
	fi

    runCmdWithErrorCheck runEngineCmd -f "$QUERY_SCRIPT"
	return $?
}


query_run_clean_method () {
	runCmdWithErrorCheck runEngineCmd -e "DROP VIEW IF EXISTS $TEMP_TABLE; DROP TABLE IF EXISTS $RESULT_TABLE1; DROP TABLE IF EXISTS $RESULT_TABLE2;"
	return $?
}

query_run_validate_method () {
	# perform exact result validation if using SF 1, else perform general sanity check
	if [ "$BIG_BENCH_SCALE_FACTOR" -eq 1 ]
	then
		local VALIDATION_PASSED="1"

		for file in "$VALIDATION_RESULTS_DIR/1"/*
		do
			local CURRENT_RESULT_FILENAME="`basename "$file"`"
			if ! hadoop fs -test -e "$RESULT_DIR1/$CURRENT_RESULT_FILENAME"
			then
				echo "File $RESULT_DIR1/$CURRENT_RESULT_FILENAME not found in HDFS."
				VALIDATION_PASSED="0"
				continue
			fi
			if diff "$file" <(hadoop fs -cat "$RESULT_DIR1/$CURRENT_RESULT_FILENAME")
			then
				echo "Validation of $CURRENT_RESULT_FILENAME passed: Query 1 returned correct results"
			else
				echo "Validation of $CURRENT_RESULT_FILENAME failed: Query 1 returned incorrect results"
				VALIDATION_PASSED="0"
			fi
		done
		for file in "$VALIDATION_RESULTS_DIR/2"/*
		do
			local CURRENT_RESULT_FILENAME="`basename "$file"`"
			if ! hadoop fs -test -e "$RESULT_DIR2/$CURRENT_RESULT_FILENAME"
			then
				echo "File $RESULT_DIR2/$CURRENT_RESULT_FILENAME not found in HDFS."
				VALIDATION_PASSED="0"
				continue
			fi
			if diff "$file" <(hadoop fs -cat "$RESULT_DIR2/$CURRENT_RESULT_FILENAME")
			then
				echo "Validation of $CURRENT_RESULT_FILENAME passed: Query 2 returned correct results"
			else
				echo "Validation of $CURRENT_RESULT_FILENAME failed: Query 2 returned incorrect results"
				VALIDATION_PASSED="0"
			fi
		done
		if [ "$VALIDATION_PASSED" -eq 1 ]
		then
			echo "Validation passed: Query results are OK"
		else
			echo "Validation failed: Query results are not OK"
		fi
	else
		if hadoop fs -test -e "$RESULT_DIR1/000000_0"
		then
			if [ `hadoop fs -cat "$RESULT_DIR1/000000_0" | head -n 10 | wc -l` -ge 1 ]
			then
				echo "Validation passed: Query 1 returned results"
			else
				echo "Validation failed: Query 1 did not return results"
			fi
		else
			echo "File $RESULT_DIR1/000000_0 not found in HDFS."
		fi
		if hadoop fs -test -e "$RESULT_DIR2/000000_0"
		then
			if [ `hadoop fs -cat "$RESULT_DIR2/000000_0" | head -n 10 | wc -l` -ge 1 ]
			then
				echo "Validation passed: Query 2 returned results"
			else
				echo "Validation failed: Query 2 did not return results"
			fi
		else
			echo "File $RESULT_DIR2/000000_0 not found in HDFS."
		fi
	fi
}
