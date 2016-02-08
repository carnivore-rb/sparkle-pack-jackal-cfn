SparkleFormation.new(:jackal_bus) do

  AWSTemplateFormatVersion '2010-09-09'
  description 'Jackal CFN Bus'

  dynamic!(:sqs_queue, :jackal)

  dynamic!(:sns_topic, :jackal) do
    properties.subscription array!(
      ->{
        endpoint attr!(:jackal_sqs_queue, :arn)
        protocol 'sqs'
      }
    )
  end

  dynamic!(:sqs_queue_policy, :jackal) do
    properties do
      policy_document do
        version '2012-10-17'
        id 'jackal-sns-policy'
        statement array!(
          ->{
            sid 'jackal-sns-access'
            effect 'Allow'
            principal '*'
            action ['sqs:SendMessage']
            resource '*'
            condition.arnEquals.set!('aws:SourceArn', ref!(:jackal_sns_topic))

          }
        )
      end
      queues [ref!(:jackal_sqs_queue)]
    end
  end

  outputs do
    jackal_service_token.value ref!(:jackal_sns_topic)
    jackal_sns_arn.value ref!(:jackal_sns_topic)
    jackal_sns_topic.value attr!(:jackal_sns_topic, :topic_name)
    jackal_sqs_arn.value attr!(:jackal_sqs_queue, :arn)
    jackal_sqs_http.value ref!(:jackal_sqs_queue)
    jackal_sqs_queue_name.value attr!(:jackal_sqs_queue, :queue_name)
  end
end
