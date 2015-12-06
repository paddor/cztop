require "guard/rspec/dsl"

# Start using
#
#   bundle exec guard -g doc & bundle exec guard -g spec
#
# This way you get parallel execution, so
# * documentation is regenerated immediately
# * specs are run immediately

README_FILE = %r{^README\.md}

# set these later using help from guard-rspec
ruby_lib_files = nil
spec_files     = nil

# I don't need no shell that hogs my CPU whenever I hit return.
interactor :off

group :spec do
  guard :rspec, cmd: "bundle exec rspec" do
    dsl = Guard::RSpec::Dsl.new(self)

    # RSpec files
    rspec = dsl.rspec
    watch(rspec.spec_helper) { rspec.spec_dir }
    watch(rspec.spec_support) { rspec.spec_dir }
    watch(rspec.spec_files)
    spec_files = rspec.spec_files

  #  # Ruby files
    ruby = dsl.ruby
    watch(ruby.lib_files) { |m| rspec.spec.(m[1]) }
    ruby_lib_files = ruby.lib_files
  end


  puts "README pattern: %p" % README_FILE
  puts "ruby lib files pattern: %p" % ruby_lib_files
  puts "spec files pattern: %p" % spec_files
end

group :syntax_check do
  guard :shell do
    # check Ruby syntax
    watch(Regexp.union(ruby_lib_files, spec_files)) do |m|
      puts "Checking Ruby syntax of %p ..." % m[0]
      if not system("ruby -c #{m[0]}")
        n "#{m[0]} is incorrect", 'Ruby Syntax', :failed
      end
    end
  end
end

YARD_OPTS = "--use-cache .yardoc/cache.db"

# KISS. guard-yard doesn't work the way I want.
# @see https://github.com/panthomakos/guard-yard/issues/20
group :doc do
  guard :shell do
    # regenreate documentation
    watch(Regexp.union(README_FILE, ruby_lib_files)) do |m|
      puts "Regenerating documentation for #{m[0].inspect} ..."
      system("yard doc #{YARD_OPTS} %s" % m[0])
    end
  end
end
