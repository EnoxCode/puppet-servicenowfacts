# encoding: utf-8
require 'faraday'
require 'json'
require 'yaml'

@configfile = File.join(File.dirname(Puppet.settings[:config]), 'servicenowfacts.yml')
raise('ERROR file does not exists: ' + @configfile) unless File.exist?(@configfile)

@config = YAML.load_file(@configfile)

# Setting CONSTANTS from the YAML Config file
SN_INSTANCE = @config['servicenow']['instance']
SN_USER = @config['servicenow']['user']
SN_WEBSERVICE = @config['servicenow']['webservice']
SN_PASS = @config['servicenow']['password']
SN_VARIABLES = @config['servicenow']['variables']
SN_PREFIX = @config['servicenow']['prefix']
SN_CACHEDIR = @config['servicenow']['cachedir']

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
# def getServiceNowResponse(conn)
begin
  response = conn.get do |req|
    req.url "#{SN_WEBSERVICE}/#{TABLE}"
    req.params['sysparm_query'] = "name=#{OS_HOSTNAME}"
    # req.params['sysparm_query'] = "name=aaic"
    req.params['sysparm_limit'] = 1
    req.headers['Content-Type'] = 'application/json'
  end
rescue Faraday::Error => e
  raise('ERROR Could not connect to ServiceNow: ' + e)
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

# TODO: Implement error control and test on windows.
def create_cache(dir, hostname, cache)
  # Let's create the cache directory if it does exists.
  Dir.mkdir(dir) unless File.exist?(dir)

  # Create the file and fill it with the cache
  cachefilename = File.join(dir, "#{hostname}.yml")
  cachefile = File.new(cachefilename, 'w+')
  cachefile.write(cache)
  cachefile.close
end

# For each defined variable in the config file add a facter
result = JSON.parse(response.body)
if result['result'].count == 0
  raise("ERROR There is no result in ServiceNow in #{TABLE} for #{OS_HOSTNAME}")
end

# TODO: cache creation only if the result of  was OK.
create_cache(SN_CACHEDIR, OS_HOSTNAME, result['result'][0])

SN_VARIABLES.each do |item|
  # TODO: add variables only if no cache hit otherwise use cache.
  add_servicenow_fact(item, result['result'][0][item])
end
