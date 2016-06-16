#!/usr/bin/env ruby
require 'json'
require 'highline'
require 'assumer'

# new cli boss
cli = HighLine.new

# We will set environment vars and not have to ask these questions each time
# or we can configure from scratch
cli.choose do |menu|
  menu.prompt = "Do you want to enter your settings, or use values in config?  "
  menu.choice(:config) {
    # push the config values into the variables
    @aws_username = ENV['AWS_USERNAME']
    @aws_account_number = ENV['AWS_ACCOUNT_NUMBER']
    @aws_region = ENV['AWS_REGION'] # 'us-west-2'
    @aws_profile = ENV['AWS_PROFILE'] # 'dso'

  }
  menu.choice(:enter) {
    cli.say("Okay, here we go.")
    @aws_username = cli.ask("Please enter your AWS username:", String)
    # lulz.
    system({"VAL" => @aws_username}, "echo 'AWS_USERNAME=$VAL' >> ~/.bash_profile")
    @aws_account_number = cli.ask("Please enter your AWS account number:", String)
    ENV['AWS_ACCOUNT_NUMBER'] = @aws_account_number
    system({"VAL" => @aws_account_number}, "export AWS_ACCOUNT_NUMBER=$VAL")
    @aws_region = cli.ask("Please enter your AWS account region:", String)
    system({"VAL" => @aws_region}, "export AWS_REGION=$VAL")
    ENV['AWS_REGION'] = @aws_region
    @aws_profile = cli.ask("Please enter your AWS profile:", String) { |q| q.default = "dso" }
    system({"VAL" => @aws_profile}, "export AWS_PROFILE=$VAL")
    ENV['AWS_PROFILE'] = @aws_profile


  }
end

@aws_username = 'student99'
@aws_account_number = '100352119871'
@aws_region = 'us-west-2'
@aws_profile = 'dso'



# get their MFA token for the first command.
# mfa_token = cli.ask("Please enter your MFA token:", Integer)

# confirm that they want to use all of the default stuff.
# and if that random shit is set, unset it first, becuase yuck.
puts "arn:aws:iam::{@aws_account_number}:role/dso/ctrl/my-app/CTL-my-app-DeploymentAdmin",

# First Jump
control_creds = Assumer::Assumer.new(
  region: @aws_region,
  account: @aws_account_number,
  role: "arn:aws:iam::#{@aws_account_number}:role/dso/ctrl/my-app/CTL-my-app-DeploymentAdmin",
  # if you are using MFA, this will be the ARN for the device
  serial_number: "arn:aws:iam::#{@aws_account_number}:mfa/#{@aws_username}",
  profile: @aws_profile # if you don't want to use environment variables or the default credentials in your ~/.aws/credentials file
)
puts control_creds.inspect





#<Assumer::Assumer:0x007f34953c1ad8 @region="us-west-2", @account="100352119871",
# @role="arn:aws:iam::100352119871:role/dso/ctrl/my-app/CTL-my-app-DeploymentAdmin",
# @sts_client=#<Aws::STS::Client>, @serial_number="arn:aws:iam::100352119871:mfa/student99",
# @assume_role_credentials=#<Aws::AssumeRoleCredentials:0x007f3495b176c0
# @assume_role_params={:role_arn=>"arn:aws:iam::100352119871:role/dso/ctrl/my-app/CTL-my-app-DeploymentAdmin",
# :role_session_name=>"AssumedRole", :serial_number=>"arn:aws:iam::100352119871:mfa/student99",
# :token_code=>"070145"}, @client=#<Aws::STS::Client>, @mutex=#<Thread::Mutex:0x007f3495b17530>,
# @credentials=#<Aws::Credentials access_key_id="ASIAJCF6BCQYMIEYVFXQ">, @expiration=2016-06-15 19:30:39 UTC>>


#Second jump
target_creds = Assumer::Assumer.new(
  region: @aws_region,
  account: @aws_account_number,
  role: 'arn:aws:iam::717986480831:role/human/dso/TGT-dso-DeploymentAdmin',
  credentials: control_creds
)

puts "================================="

puts target_creds.inspect
# ^ need to bust this one open to get the session token and other shit for the following json code.
puts "===========assume role creds======================"

puts target_creds.assume_role_credentials
puts target_creds.assume_role_credentials.access_key_id
puts target_creds.assume_role_credentials.secret_access_key
puts target_creds.assume_role_credentials.session_token

puts target_creds.assume_role_credentials.inspect
access_key_id =  target_creds.assume_role_credentials.access_key_id
secret_access_key =  target_creds.assume_role_credentials.secret_access_key
session_token = target_creds.assume_role_credentials.session_token

puts "================================="


# here's code I didn't write
# but modified to use the variables above
issuer_url = 'gui.rb'
console_url = 'https://console.aws.amazon.com/'
signin_url = 'https://signin.aws.amazon.com/federation'

session_json = { sessionId: access_key_id,
                 sessionKey: secret_access_key,
                 sessionToken: session_token }.to_json
get_signin_token_url = signin_url + '?Action=getSigninToken' + '&SessionType=json&Session=' + CGI.escape(session_json)
returned_content = Net::HTTP.get(URI.parse(get_signin_token_url))

signin_token = JSON.parse(returned_content)['SigninToken']
signin_token_param = '&SigninToken=' + CGI.escape(signin_token)

issuer_param = '&Issuer=' + CGI.escape(issuer_url)
destination_param = '&Destination=' + CGI.escape(console_url)
login_url = signin_url + '?Action=login' + signin_token_param + issuer_param + destination_param

puts "\n\nCopy and paste this URL into your browser:\n#{login_url}"
