SparkleFormation.dynamic(:jackal_sqs) do |name, args={}|

  result = dynamic!(:sqs_queue, name)

  if(args[:sns_enabled])
    dynamic!(:sns_topic, name) do
      properties.subscription array!(
        ->{
          endpoint attr!("#{name}_sqs_queue".to_sym, :arn)
          protocol 'sqs'
        }
      )
      depends_on!("#{name}_sqs_queue".to_sym)
    end
  end

  dynamic!(:sqs_queue_policy, name).properties do
    policy_document do
      version '2012-10-17'
      id "#{name}-jackal-sqs-policy"
      statement array!(
        ->{
          sid "#{name}-jackal-sqs-account-send-access"
          effect 'Allow'
          principal '*'
          action ['sqs:SendMessage']
          resource '*'
          if(args[:sns_enabled])
            condition.arnEquals.set!('aws:SourceArn', ref!("#{name}_sns_topic".to_sym))
          end
        }
      )
    end
    queues [ref!("#{name}_sqs_queue".to_sym)]
  end

  outputs do
    if(args[:sns_enabled])
      set!("#{name}_service_token".to_sym).value ref!("#{name}_sns_topic".to_sym)
      set!("#{name}_sns_arn".to_sym).value ref!("#{name}_sns_topic".to_sym)
      set!("#{name}_sns_topic".to_sym).value attr!("#{name}_sns_topic".to_sym, :topic_name)
    end
    set!("#{name}_sqs_arn".to_sym).value attr!("#{name}_sqs_queue".to_sym, :arn)
    set!("#{name}_sqs_http".to_sym).value ref!("#{name}_sqs_queue".to_sym)
    set!("#{name}_sqs_queue_name".to_sym).value attr!("#{name}_sqs_queue".to_sym, :queue_name)
  end

  result
end
