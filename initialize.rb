require 'json'

def welcome_ascii
  <<~ASCII

                      /(((((((
                    //((((((
                  /////(((
              ////////
    %%%%%%%%    ////////
      %%%%%%%%    ////////
        %%%%%%%%    ////////
            %%%%%%%%   ////////
          &&%%%%%%
        &&&&&%%%
      &&&&&&&%
    &&&&&&&%

     _            _     _
    | | __ _ _ __(_) __| | __ _  ___
    | |/ _` | '__| |/ _` |/ _` |/ _ \\
    | | (_| | |  | | (_| | (_| |  __\/
    |_|\\__,_|_|  |_|\\__,_|\\__,_|\\___|

  ASCII
end

def init
  if ARGV.length == 1
    input_filename = ARGV[0]
  else
    puts "Invalid arguments"
    return
  end
  resource_names = JSON.parse(File.read(input_filename))
  resource_names["LARIDAE_CLUSTER"] = "laridae_#{resource_names["IMAGE_NAME"]}_cluster"
  resource_names["LARIDAE_TASK_DEFINITION"] = "laridae_#{resource_names["IMAGE_NAME"]}_task_definition"

  puts welcome_ascii

  resources_for_initialization = resource_names.slice("REGION", "DATABASE_URL", "LARIDAE_CLUSTER", "VPC_ID", "LARIDAE_TASK_DEFINITION")
  var_flags = resources_for_initialization.map { |name, value| "-var=\"#{name}=#{value}\"" }.join(' ')
  puts "Preparing to create AWS resources..."
  `terraform init`
  `terraform destroy #{var_flags} --auto-approve`
  puts "Creating AWS resources..."
  `terraform apply #{var_flags} --auto-approve`

  resource_names["LARIDAE_SECURITY_GROUP"] = `terraform output security_group_id`.gsub('"', "").chomp
  resource_names["ACCESS_KEY_ID"] = `terraform output ecs_access_key_id`.gsub('"', "").chomp
  resource_names["SECRET_ACCESS_KEY"] = `terraform output ecs_secret_access_key`.gsub('"', "").chomp

  puts "Altering database security group to allow access from Laridae task..."
  `aws ec2 authorize-security-group-ingress --region #{resource_names["REGION"]} --group-id #{resource_names["DATABASE_SECURITY_GROUP"]} --protocol tcp --port 5432 --source-group #{resource_names["LARIDAE_SECURITY_GROUP"]}`
  secret = resource_names.map { |key, value| "#{key}=#{value}"}.join("\n")
  puts <<~HEREDOC
  Initialization complete!

  Add a secret to your Github repo called LARIDAE_RESOURCE_NAMES with the following content:

  #{secret}
  HEREDOC
end

init