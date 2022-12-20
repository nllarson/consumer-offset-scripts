#Consumer Group Offset Update Scripts
---

`timestamp-offset-update.sh`
This script will find the latest offset for a consumer group on a given topicA.  Then consume that record and grab of a pre-determined timestamp field that is present in the payload.
From there, the script will gather all the partitions timestamps, find the earliest one, and create a statement to set the consumer group offset for topicB.

You will want to update the `RECORD_FIELD` variable in the script to match the JSON field path that you want to use to select your *timestamp* value.


`maxlag-offset-update.sh`
This script will find the largest consumer lag for a given consumer group on topicA and then produce an update statement to shift the offsets for the consumer group on TopicB.

The `OFFSET_BACKOFF` variable can be tweaked to move the offset away from the Max Lag.  It is default to 100, so if Max Lag found is 500, the script will generate a shift value of 600.  This allows you to be able to easily adjust the max lag if needed.


## Getting Started
You will need to create a file `kafka.properties` that has the connectivity information for your kafka cluster.  See `sample-kafka.properties` for a template.  Just make sure to name it `kafka.properties` or change the `CONFLUENT_CONFIG_FILE` variable in the script.

In each script, you can update the `CONFLUENT_PATH` variable to point to you installment of the Confluent toolkit.

If you do not have the Confluent platform, this can be downloaded here:
`https://docs.confluent.io/platform/current/installation/installing_cp/zip-tar.html#install-cp-using-zip-and-tar-archives`

### Script Arguments
Each script takes 3 arguments to execute.  The `consumer group`, `topicA`, and `topicB`.

Example:
`./maxlag-offset-update.sh consumer-group-abc, myOldTopic, theNewTopic`






