#
# Cookbook Name:: rubygems-people
# Recipe:: default
#

include_recipe 'user'

meg_balancer_host = search('node', "roles:balancer AND chef_environment:#{node.chef_environment}")[0]['ipaddress'] rescue ''
meg_app_host = search('node', "roles:app AND chef_environment:#{node.chef_environment}").sort[0]['ipaddress'] rescue ''

users = data_bag('users')
sysadmins = []
users.each do |user_name|
  user = data_bag_item('users', user_name)

  if (user['action'] && user['action'] == 'remove') || \
   (!user['environments'].include?(node.chef_environment))
    user_account user['username'] do
      action :remove
      only_if "/usr/bin/id -u #{user['username']}"
    end
  else
    sysadmins << user['username'] if user['admin']
    user_account user['username'] do
      comment   user['comment']
      password  user['password']
      ssh_keys  user['ssh_keys']
      shell     user['shell'] ? user['shell'] : '/bin/bash'
    end

    template "/home/#{user['username']}/.bashrc" do
      source 'bashrc.erb'
      owner user['username']
      group user['username']
      variables(
        environment: node.chef_environment,
        meg_balancer_host: meg_balancer_host,
        meg_app_host: meg_app_host
      )
    end

    # If a user does stuff like setting up their $HOME via a custom recipe then
    # their data bag should have 'has_recipe' set to true. Then they can have
    # a recipe in this cookbook which matches their username.
    include_recipe "rubygems-people::#{user['username']}" if user['has_recipe']
  end
end

group 'sysadmin' do
  gid 2300
  members sysadmins
end

node.default['authorization']['sudo']['groups'] = ['sysadmin']
node.default['authorization']['sudo']['include_sudoers_d'] = true
node.default['authorization']['sudo']['passwordless'] = true
include_recipe 'sudo'

sudo 'deploy' do
  user      '%sysadmin'
  nopasswd  true
  commands  [
    '/usr/sbin/service unicorn restart',
    '/usr/sbin/service delayed_job restart',
    '/usr/bin/chef-client',
    '/bin/ln -s /etc/nginx/maintenance.html /var/www/rubygems/maintenance.html',
    '/bin/rm /var/www/rubygems/maintenance.html'
  ]
end

include_recipe 'rubygems-people::meg'
