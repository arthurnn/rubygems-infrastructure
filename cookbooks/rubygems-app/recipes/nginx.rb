#
# Cookbook Name:: rubygems-app
# Recipe:: nginx
#

node.default['nginx']['server_tokens'] = 'off'
node.default['nginx']['default_site_enabled'] = false
node.default['nginx']['package_name'] = 'nginx-extras'

include_recipe 'nginx'

template "#{node['nginx']['dir']}/sites-available/rubygems" do
  source 'nginx.conf.erb'
  owner  'root'
  group  'root'
  mode   '0644'
  variables(
    rails_env:  node.chef_environment,
    rails_root: '/applications/rubygems',
    unicorn_port: 3000,
    nginx_port: 9000
  )
  notifies :reload, 'service[nginx]'
end

nginx_site 'rubygems'

node.default['datadog']['nginx']['instances'] = [{ 'nginx_status_url' => 'http://localhost/nginx_status/' }]
include_recipe 'datadog::nginx'
