require 'mina/config/version'
require 'fileutils'
require 'yaml'
require 'mina/rvm'
require 'active_support/core_ext/hash'
require 'mina/String'


default_env = fetch(:default_env, 'staging')
config_file = 'config/deploy.yml'
set :config, YAML.load(File.open(config_file)).with_indifferent_access if File.exists? config_file
set :rails_env, ENV['to'] || :staging

unless fetch(:config).nil?
  envs = []
  fetch(:config).each {|k,v| envs << k}

  set :environments, envs
end

unless fetch(:environments).nil?
  fetch(:environments).each do |environment|
    desc "Set the environment to #{environment}."
    task(environment) do
      set :rails_env, environment
      set :branch, ENV['branch'] || fetch(:config)[fetch(:rails_env)]['branch']
      set :user, fetch(:config)[fetch(:rails_env)]['user']
      set :domain, fetch(:config)[fetch(:rails_env)]['domain']
      set :repository, fetch(:config)[fetch(:rails_env)]['repository']
      set :shared_paths, fetch(:config)[fetch(:rails_env)]['shared_paths']
      set :start_sidekiq, fetch(:config)[fetch(:rails_env)]['start_sidekiq'] if fetch(:config)[fetch(:rails_env)]['start_sidekiq']
      set :start_rpush, fetch(:config)[fetch(:rails_env)]['start_rpush']if fetch(:config)[fetch(:rails_env)]['start_rpush']

      set :deploy_to, fetch(:deploy_to) || File.join(fetch(:deploy_path), fetch(:domain))
      set :ruby_version, File.read('.ruby-version').strip!

      invoke :'rvm:use', fetch(:ruby_version)
    end
  end

  unless fetch(:environments).include?(ARGV.first)
    invoke default_env
  end
end

namespace :config do
  desc 'Create deploy config file'
  task :init do
    if File.exists?(config_file).blank?
      app_params = {}
      puts "What is your app name?"
      app_params.store(:common, {})
      app_params[:common][:app_name] = STDIN.gets.chomp
      puts "What is the ssh url for the repository?"
      app_params[:common][:repo] = STDIN.gets.chomp
      %w{staging production}.each do |stage|
        app_params.store("#{stage}".to_sym, {})
        puts "----------#{stage} Configuration----------"
        puts "What is the domain for #{stage}?"
        app_params["#{stage}".to_sym][:domain] = STDIN.gets.chomp
        puts "What is the user for #{stage}?"
        app_params["#{stage}".to_sym][:user] = STDIN.gets.chomp
        puts "What is the branch for #{stage}?"
        app_params["#{stage}".to_sym][:branch] = STDIN.gets.chomp
      end

      deploy_yml = "
          common: &common
                application_name: #{app_params[:common][:app_name]}
                repository: #{app_params[:common][:repo]}
                shared_paths: 
                  - 'config/database.yml'
                  - 'log'"

      app_params.each do |k,v|
        if(k != :common)
          deploy_yml += "
          #{k}:
                <<: *common
                domain: #{app_params[k][:domain]}
                user: #{app_params[k][:user]}
                branch: #{app_params[k][:branch]}"
        end
      end

      File.open(config_file, 'w') do |f|
        f.puts deploy_yml.dedent
      end
    end
  end
end
