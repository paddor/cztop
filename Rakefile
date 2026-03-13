require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.test_files = FileList["test/**/*_test.rb"].exclude("test/system/**/*_test.rb")
  t.warning = false
end

Rake::TestTask.new("test:system") do |t|
  t.libs << "test"
  t.pattern = "test/system/**/*_test.rb"
  t.warning = false
end

task :default => :test
