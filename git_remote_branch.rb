class Grb < Thor
  class InvalidBranchError < RuntimeError; end
  class NotOnGitRepositoryError < RuntimeError; end
  
  desc "create branch_name [origin_server]", "create a new remote branch and track it locally"
  def create(branch_name, origin = 'origin')
    current_branch = get_current_branch
    `git push #{origin} #{current_branch}:refs/heads/#{branch_name}`
    `git fetch #{origin}`
    `git branch --track #{branch_name} #{origin}/#{branch_name}`
    `git checkout #{branch_name}`
  end
  
  desc "delete branch_name [origin_server]", "delete a local and a remote branch"
  def delete(branch_name, origin = 'origin')
    current_branch = get_current_branch
    `git push #{origin} :refs/heads/#{branch_name}`
    `git checkout master` if current_branch == branch_name
    `git branch -d #{branch_name}`
  end
  
  desc "publish branch_name [origin_server]", "publish an exiting local branch"
  def publish(branch_name, origin = 'origin')
    `git push #{origin} #{branch_name}:refs/heads/#{branch_name}`
    `git fetch #{origin}`
    `git config branch.#{branch_name}.remote #{origin}`
    `git config branch.#{branch_name}.merge refs/heads/#{branch_name}`
    `git checkout #{branch_name}`
  end
  
  desc "track branch_name [origin_server]", "track an existing remote branch"
  def track(branch_name, origin = 'origin')
    current_branch = get_current_branch
    `git fetch #{origin}`
    `git checkout master` if current_branch == branch_name
    `git branch --track #{branch_name} #{origin}/#{branch_name}`
  end
  
  desc "rename branch_name [origin_server]", "rename a remote branch and its local tracking branch"
  def rename(branch_name, origin = 'origin')
    current_branch = get_current_branch
    `git push #{origin} #{current_branch}:refs/heads/#{branch_name}`
    `git fetch #{origin}`
    `git branch --track #{branch_name} #{origin}/#{branch_name}`
    `git checkout #{branch_name}`
    `git push #{origin} :refs/heads/#{current_branch}`
    `git branch -d #{current_branch}`
  end
  
  protected
    BRANCH_LISTING_COMMAND = 'git branch -l'.freeze
    
    def get_current_branch
      #This is sensitive to checkouts of branches specified with wrong case
    
      listing = CaptureFu::capture_process_output("#{BRANCH_LISTING_COMMAND}")[1]
      raise(NotOnGitRepositoryError, listing.chomp) if listing =~ /Not a git repository/i
    
      current_branch = listing.scan(/^\*\s+(.+)/).flatten.first
    
      if current_branch =~ /\(no branch\)/
        raise InvalidBranchError, ["Couldn't identify the current local branch. The branch listing was:",
          BRANCH_LISTING_COMMAND.red, 
          listing].join("\n")
      end
      current_branch.strip
    end
  
    module CaptureFu
      VERSION = '0.0.1'

      def self.capture_output(&block)
        real_out, real_err = $stdout, $stderr
        result = fake_out = fake_err = nil
        begin
          fake_out, fake_err = Helpers::PipeStealer.new, Helpers::PipeStealer.new
          $stdout, $stderr = fake_out, fake_err
          result = yield
        ensure
          $stdout, $stderr = real_out, real_err
        end
        return result, fake_out.captured, fake_err.captured
      end

      # This first implementation is only intended for batch executions.
      # You can't pipe stuff programmatically to the child process.
      def self.capture_process_output(command)

        #capture stderr in the same stream
        command << ' 2>&1' unless Helpers.stderr_already_redirected(command)

        out = `#{command}`
        return $?.exitstatus, out
      end


      private

      module Helpers

        def self.stderr_already_redirected(command)
          #Already redirected to stdout (valid for Windows)
          return true if command =~ /2>&1\s*\Z/

          #Redirected to /dev/null (this is clearly POSIX-dependent)
          return true if command =~ /2>\/dev\/null\s*\Z/

          return false
        end

        class PipeStealer < File
          attr_reader :captured
          def initialize
            @captured = ''
          end
          def write(s)
            @captured << s
          end
          def captured
            return nil if @captured.empty?
            @captured.dup
          end
        end

      end #Helper module
    end
  
end