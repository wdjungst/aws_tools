require 'rubygems'
require 'aws-sdk'
require 'yaml'
require 'optparse'

CONFIG = YAML::load_file(File.expand_path(File.dirname(__FILE__) + '/config/config.yml'))
PRICING = YAML::load_file(File.expand_path(File.dirname(__FILE__) + '/config/max_bid.yml'))
AWS.config(access_key_id: CONFIG['access_key_id'], secret_access_key: CONFIG['secret_access_key'], region: CONFIG['region'])

@max_bid = PRICING['max_bid'].to_f

def ec2_session
  AWS::EC2.new
end

def spot_instance_pricing
  @ec2.client.describe_spot_price_history(
    instance_types: ['m2.xlarge'],
    start_time: (Time.now).iso8601,
    product_descriptions: ['Linux/UNIX'],
    availability_zone: 'us-east-1b').data[:spot_price_history_set].map{ |history| history[:spot_price] }
end  

def exceed_max_bid? (current_price)
  current_price > @max_bid
end

def notify (current_price)
  puts "price $ #{current_price} is greater than max bid $#{@max_bid}"
  `echo price $#{current_price} | mail -s Spot Price exceeding $#{@max_bid} #{CONFIG['email']}`
end

def update_max_bid
  print "Enter max bid (#{@max_bid}): " 
  bid = gets.to_f
  `echo max_bid: '#{bid}' > #{File.expand_path(File.dirname(__FILE__) + '/config/max_bid.yml')}`  
  puts "max bid set to #{bid}"
end 

def poll
  @ec2 = ec2_session
  price = spot_instance_pricing.first.to_f
  exceed_max_bid?(price) ? notify(price) : puts('bid not exceeded')
end

def options
  options = {}
  optparse = OptionParser.new do |opts|
    options[:run] = false
    options[:max_bid] = false
    
    opts.on('-r', '--run', 'Poll aws for max price') do 
      options[:run] = true
    end
    opts.on('-m', '--max_bid', 'Update max bid') do
      options[:max_bid] = true
    end
    opts.on('-h', '--help', 'Display this screen') do
      puts opts
      exit
    end
  end

  optparse.parse!

  if options[:run]
    poll
  elsif options[:max_bid]
    update_max_bid
  end
end
  
options

