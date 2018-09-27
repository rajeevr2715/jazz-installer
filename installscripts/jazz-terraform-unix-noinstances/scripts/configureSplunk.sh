#!/bin/bash

jenkinsjsonpropsfile=$8

sed -i "s/{ENABLE_SPLUNK_FEATURE}/$1/g" "$jenkinsjsonpropsfile"
sed -i "s|{SPLUNK_ENDPOINT}|$2|g" "$jenkinsjsonpropsfile"
sed -i "s/{SPLUNK_TOKEN}/$3/g" "$jenkinsjsonpropsfile"
sed -i "s/{SPLUNK_INDEX}/$4/g" "$jenkinsjsonpropsfile"
sed -i "s|{KINESIS_LOGS_STREAM_DEV}|$5|g" "$jenkinsjsonpropsfile"
sed -i "s|{KINESIS_LOGS_STREAM_STG}|$6|g" "$jenkinsjsonpropsfile"
sed -i "s|{KINESIS_LOGS_STREAM_PROD}|$7|g" "$jenkinsjsonpropsfile"
