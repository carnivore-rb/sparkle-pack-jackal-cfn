SparkleFormation.new(:jackal_nellie, :inherit => :jackal_cfn) do

  description 'Jackal Nellie Service'

  parameters do
    slack_webhook_url.type 'String'
    github_access_token.type 'String'
    jackal_custom_packages.default << ',git'
  end

  sqs_resource = dynamic!(:jackal_sqs, :nellie)

  resources.jackal_iam_user.properties.policies.concat array!(
    ->{
      policy_name 'nellie-access'
      policy_document.statement array!(
        ->{
          effect 'Allow'
          action 'sqs:*'
          resource attr!(sqs_resource.resource_name!, :arn)
        }
      )
    }
  )

  dynamic!(:iam_user, :remote_service).properties do
    path '/'
    policies array!(
      ->{
        policy_name 'remote-queue-access'
        policy_document.statement array!(
          ->{
            effect 'Allow'
            action 'sqs:SendMessage'
            resource attr!(sqs_resource.resource_name!, :arn)
          }
        )
      }
    )
  end

  dynamic!(:iam_access_key, :remote_service).properties.user_name ref!(:remote_service_iam_user)

  resources.jackal_cfn_jackal_image_ec2_instance do
    metadata('AWS::CloudFormation::Init') do
      camel_keys_set!(:auto_disable)
      config do
        commands('06_jackal_install') do
          command << ' carnivore-actor jackal-github jackal-code-fetcher jackal-nellie jackal-slack jackal-github-kit'
        end
        files('/etc/jackal/configuration.json') do
          content do
            jackal do
              require.concat [
                'carnivore-actor',
                'jackal/callback',
                'jackal-github',
                'jackal-code-fetcher',
                'jackal-nellie',
                'jackal-slack',
                'jackal-github-kit'
              ]
              assets.connection do
                provider 'local'
                credentials do
                  object_store_root '/tmp/jackal-store'
                  bucket 'assets'
                end
              end
              github.access_token ref!(:github_access_token)
              github do
                sources do
                  input do
                    type 'sqs'
                    args do
                      queues [
                        ref!(sqs_resource.resource_name!)
                      ]
                      fog do
                        aws_access_key_id ref!(:jackal_iam_access_key)
                        aws_secret_access_key attr!(:jackal_iam_access_key, :secret_access_key)
                        region region!
                      end
                    end
                  end
                  output do
                    type 'actor'
                    args do
                      remote_name 'jackal_code_fetcher_input'
                    end
                  end
                end
                formatters [
                  'Jackal::Github::Formatter::CodeFetcher'
                ]
                callbacks [
                  'Jackal::Github::Eventer'
                ]
              end
              code_fetcher do
                sources.input.type 'actor'
                sources.output do
                  type 'actor'
                  args do
                    remote_name 'jackal_nellie_input'
                  end
                end
                callbacks [
                  'Jackal::CodeFetcher::GitHub'
                ]
              end
              nellie do
                sources.input.type 'actor'
                sources.output do
                  type 'actor'
                  args do
                    remote_name 'jackal_slack_input'
                  end
                end
                formatters [
                  'Jackal::Nellie::Formatter::GithubCommitComment',
                  'Jackal::Nellie::Formatter::SlackComment'
                ]
                callbacks [
                  'Jackal::Nellie::Processor'
                ]
              end
              slack do
                config.webhook_url ref!(:slack_webhook_url)
                sources.input.type 'actor'
                sources.output do
                  type 'actor'
                  args do
                    remote_name 'jackal_github_kit_input'
                  end
                end
                callbacks [
                  'Jackal::Slack::Notification'
                ]
              end
              github_kit do
                sources.input.type 'actor'
                callbacks [
                  'Jackal::GithubKit::Hubber'
                ]
              end
            end
          end
        end
      end
    end
  end

  dynamic!(:cloud_watch_alarm, :jackal) do
    properties do
      actions_enabled true
      alarm_actions [ref!(:jackal_auto_scaling_scaling_policy)]
      alarm_description 'Nellie Kickstart'
      comparison_operator 'GreaterThanOrEqualToThreshold'
      evaluation_periods 2
      metric_name 'ApproximateNumberOfMessagesVisible'
      namespace 'AWS/SQS'
      dimensions array!(
        ->{
          name 'QueueName'
          value attr!(sqs_resource.resource_name!, :queue_name)
        }
      )
      period 60
      statistic 'Average'
      threshold 1
    end
  end

  outputs do
    remote_service_aws_id.value ref!(:remote_service_iam_access_key)
    remote_service_aws_key.value attr!(:remote_service_iam_access_key, :secret_access_key)
  end

end
