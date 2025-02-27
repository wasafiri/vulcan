namespace :db do
  desc "Execute SQL directly"
  task :execute_sql, [ :sql ] => :environment do |t, args|
    ActiveRecord::Base.connection.execute(args[:sql])
  end
end
