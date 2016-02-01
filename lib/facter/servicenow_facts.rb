# encoding: utf-8
require 'faraday'
require 'json'
require 'yaml'

@configfile = './config.yml'
fail('ERROR file does not exists: ' + @configfile) unless File.exist?(@configfile)

@config = YAML.load_file(@configfile)

# Setting CONSTANTS from the YAML Config file
SN_INSTANCE = @config['servicenow']['instance']
SN_USER = @config['servicenow']['user']
SN_WEBSERVICE = @config['servicenow']['webservice']
SN_PASS = @config['servicenow']['password']
SN_VARIABLES = @config['servicenow']['variables']
SN_PREFIX = @config['servicenow']['prefix']

# Retrieving Host and Kernel from facter
OS_KERNEL = Facter.value(:kernel)
OS_HOSTNAME = Facter.value(:hostname)

# Retrieving table name based upon kernel
TABLE = @config['servicenow'][OS_KERNEL.downcase + '_table']

# Build connection using faradady
conn = Faraday.new(url: SN_INSTANCE.to_s, ssl: { verify: false }) do |faraday|
  faraday.request :url_encoded
  faraday.basic_auth(SN_USER.to_s, SN_PASS.to_s)
  # faraday.response :logger
  faraday.adapter Faraday.default_adapter
end

# Build Response using hostname and table name from the constants
begin
  response = conn.get do |req|
    req.url "#{SN_WEBSERVICE}/#{TABLE}"
    req.params['sysparm_query'] = "name=#{OS_HOSTNAME}"
    # req.params['sysparm_query'] = "name=aaic"
    req.params['sysparm_limit'] = 1
    req.headers['Content-Type'] = 'application/json'
  end
rescue Faraday::Error => e
  raise ('ERROR Could not connect to ServiceNow: ' + e)
end

# Function to add Fact to facter
def add_servicenow_fact(name, value)
  name = SN_PREFIX + name
  Facter.add(name) do
    setcode do
      value
    end
  end
end

# For each defined variable in the config file add a facter
result = JSON.parse(response.body)
if result['result'].count == 0
  fail "ERROR There is no result in ServiceNow in #{TABLE} for #{OS_HOSTNAME}"
end

for item in SN_VARIABLES
  add_servicenow_fact(item, result['result'][0][item])
end
