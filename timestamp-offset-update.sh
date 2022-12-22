#!/bin/sh

# Plan
# 1) Determine last consumed offset from consumer group on topic A (old)
# 2) Consume a single record at offset (from step 1) - 100 (this number is changeable, 
#         and used to give us a buffer) on topic A
#        From this record, grab the timestamp (createTime)
# 3) Update Consumer Group on Topic B to offset closest to this time.


CONFLUENT_PATH=/Users/nllarson/tools/confluent/current/bin
CONFLUENT_CONFIG_FILE=kafka.properties
OFFSET_BACKOFF=100
RECORD_FIELD=".ORDERTIME.long"

usage()
{
    echo "Usage: timestamp-offset-update.sh <consumer group> <topicA> <topicB>";
    exit 1;
}

if [ $# -ne 3 ] ; then
    usage
else
    consumerGroupA=$1
    topicA=$2
    topicB=$3
fi

## DEBUG
# echo "Consumer Group: $consumerGroupA";
# echo "Topic A: $topicA";
# echo "Topic B: $topicB";

# Find Current Offsets for Consumer Group
aOffsets=`$CONFLUENT_PATH/kafka-consumer-groups --command-config $CONFLUENT_CONFIG_FILE  --bootstrap-server $(grep "^\s*bootstrap.server" $CONFLUENT_CONFIG_FILE | tail -1)    --describe --group $consumerGroupA`
currentOffsets=($(echo "$aOffsets" |  awk 'NR>2 {printf "%s,%s,%s\n", $1, $3, $4}'))
searchValues=()
earliestTimestamp=""

# Find value in record at searchOffset (current offset - 100)
for offset in "${currentOffsets[@]}"
do
    IFS=','
    read -ra line <<< "$offset"
    searchOffset=$((${line[2]} - ${OFFSET_BACKOFF}))

    valAtOffset=`$CONFLUENT_PATH/kafka-avro-console-consumer \
    --consumer.config $CONFLUENT_CONFIG_FILE \
    --topic $topicA --partition ${line[1]} --offset $searchOffset --max-messages 1 \
    --bootstrap-server $(grep "^\s*bootstrap.server" $CONFLUENT_CONFIG_FILE | tail -1) \
    --property schema.registry.url=$(grep "^schema.registry.url" $CONFLUENT_CONFIG_FILE | cut -d'=' -f2) \
    --property basic.auth.credentials.source=USER_INFO \
    --property basic.auth.user.info=$(grep "^basic.auth.user.info" $CONFLUENT_CONFIG_FILE | cut -d'=' -f2) | jq '. | '${RECORD_FIELD}''`
    
    searchValues+=("${line[1]},${valAtOffset}")

    if [ ! "${earliestTimestamp}" ] || (("${valAtOffset}" <= "$earliestTimestamp"))
    then
        earliestTimestamp=${valAtOffset};
    fi

done

echo "-----------"
echo "\n"
echo "\n"
echo "\n"
# Display Results
echo "Topic A: ${topicA} Current Offset for Consumer Group ${consumerGroup}"
for offset in "${currentOffsets[@]}"
do
    IFS=','
    read -ra line <<< "$offset"
    echo "Partition: ${line[1]} -- Offset: ${line[2]}"
done

echo "\n"

echo "Topic A: createTime at Current Offset for Consumer Group ${consumerGroup}"
for result in "${searchValues[@]}"
do
    IFS=','
    read -ra line <<< "$result"
    echo "Partition: ${line[0]} -- createTime: ${line[1]}"
done

setTime=`date -r $earliestTimestamp +"%Y-%m-%d %H:%M:%S"`

echo "\n"
echo "Earliest Processed Timestamp: $earliestTimestamp";
echo "Formatted: $setTime"
echo "\n"
echo "Consumer Group Update Statements"
echo "---------------------------------"
echo "kafka-consumer-groups --bootstrap-server $(grep "^\s*bootstrap.server" $CONFLUENT_CONFIG_FILE | tail -1) --group $consumerGroup --topic $topicB --reset-offsets --to-datetime $setTime"







