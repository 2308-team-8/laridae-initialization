require 'ruby-terraform'

require 'json'
INPUT_FILENAME = "./initialization_inputs.json"

resource_names = JSON.parse(File.read(INPUT_FILENAME))
resource_names["LARIDAE_CLUSTER"] = "laridae_#{resource_names["IMAGE_NAME"]}_cluster"
resource_names["LARIDAE_TASK_DEFINITION"] = "laridae_#{resource_names["IMAGE_NAME"]}_task_definition"

resources_for_initialization = resource_names.slice("REGION", "DATABASE_URL", "LARIDAE_CLUSTER", "VPC_ID", "LARIDAE_TASK_DEFINITION")
puts "Creating necessary AWS resources..."

RubyTerraform.init
RubyTerraform.destroy(chdir: __dir__, vars: resources_for_initialization, auto_approve: true)
RubyTerraform.apply(chdir: __dir__, vars: resources_for_initialization, auto_approve: true)

resource_names["LARIDAE_SECURITY_GROUP"] = RubyTerraform.output(name: "security_group_id").gsub('"', "")
runner_access_key_id = RubyTerraform.output(name: "ecs_access_key_id").gsub('"', "")
runner_secret_access_key = RubyTerraform.output(name: "ecs_secret_access_key").gsub('"', "")

`aws ec2 authorize-security-group-ingress --region #{resource_names["REGION"]} --group-id #{resource_names["DATABASE_SECURITY_GROUP"]} --protocol tcp --port 5432 --source-group #{resource_names["LARIDAE_SECURITY_GROUP"]}`

secret = resource_names.map { |key, value| "#{key}=#{value}"}.join("\n")
puts <<~HEREDOC

======================================================================================

Add a secret to your Github repo called AWS_RESOURCE_NAMES with the following content:

#{secret}

and one called AWS_ACCESS_KEY_ID with the following string:
#{runner_access_key_id}
and another called AWS_SECRET_ACCESS_KEY with
#{runner_secret_access_key}
HEREDOC