#!/bin/sh

# Plan
# 1) Determine last consumed offset from consumer group on topic A (old)
# 2) Consume a single record at offset (from step 1) - 100 (this number is changeable) on topic A
# 3) Consume records from topic B (new), from beginning or some other offset, until timestamp of createTime found in record obtained in step 2. - record this offset
# 4) Set consumer group offset to offset found in step 3


CONFLUENT_PATH=/Users/nllarson/tools/confluent/current/bin
CONFLUENT_CONFIG_FILE=kafka.properties
OFFSET_BACKOFF=100
RECORD_FIELD=".ORDERID.int"

usage()
{
    echo "Usage: reset.sh <consumer group> <topicA> <topicB>";
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
aOffsets=`$CONFLUENT_PATH/kafka-consumer-groups --command-config $CONFLUENT_CONFIG_FILE  --bootstrap-server $(grep "^\s*bootstrap.server" $CONFLUENT_CONFIG_FILE | tail -1)  --describe --group $consumerGroupA`
currentOffsets=($(echo "$aOffsets" |  awk 'NR>2 {printf "%s,%s,%s\n", $1, $3, $4}'))
searchValues=()

# Find value in record at searchOffset (current offset - 100)
for offset in "${currentOffsets[@]}"
do
    IFS=','
    read -ra line <<< "$offset"
    echo "Partition ${line[1]} -- Offset ${line[2]}"
    searchOffset=$((${line[2]} - ${OFFSET_BACKOFF}))
    echo "Search offset - ${searchOffset}"

    valAtOffset=`$CONFLUENT_PATH/kafka-avro-console-consumer \
    --consumer.config $CONFLUENT_CONFIG_FILE \
    --topic $topicA --partition ${line[1]} --offset $searchOffset --max-messages 1 \
    --bootstrap-server $(grep "^\s*bootstrap.server" $CONFLUENT_CONFIG_FILE | tail -1) \
    --property schema.registry.url=$(grep "^schema.registry.url" $CONFLUENT_CONFIG_FILE | cut -d'=' -f2) \
    --property basic.auth.credentials.source=USER_INFO \
    --property basic.auth.user.info=$(grep "^basic.auth.user.info" $CONFLUENT_CONFIG_FILE | cut -d'=' -f2) | jq '. | '${RECORD_FIELD}''`
    
    searchValues+=("${line[1]},${valAtOffset}")
done

for record in "${searchValues[@]}"
do
    IFS=','
    read -ra line <<< "$record"
    echo "Partition: ${line[0]} -- Search Value: ${line[1]}"

    #print.offset=true
    $CONFLUENT_PATH/kafka-avro-console-consumer \
    --consumer.config $CONFLUENT_CONFIG_FILE \
    --topic $topicA --partition ${line[1]} --offset $searchOffset --max-messages 1 \
    --bootstrap-server $(grep "^\s*bootstrap.server" $CONFLUENT_CONFIG_FILE | tail -1) \
    --property schema.registry.url=$(grep "^schema.registry.url" $CONFLUENT_CONFIG_FILE | cut -d'=' -f2) \
    --property basic.auth.credentials.source=USER_INFO \
    --property basic.auth.user.info=$(grep "^basic.auth.user.info" $CONFLUENT_CONFIG_FILE | cut -d'=' -f2) | jq '. | '${RECORD_FIELD}''
    

done






