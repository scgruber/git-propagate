require 'rake'

module GitPropagate
  include FileUtils

  def branch(branchName, &blk)
    sh "git checkout #{branchName}" do |ok, res|
      if !ok
        puts "Checkout of #{branchName} failed (status = #{res.exitstatus})"
        exit
      end
    end

    # Rebase if we have a valid parent
    if defined? @parentBranchName
      puts "Rebasing #{@parentBranchName} onto #{branchName}"
      sh "git rebase #{@parentBranchName}" do |ok, res|
        if !ok
          puts "Rebase of #{@parentBranchName} onto #{branchName} failed (status = #{res.exitstatus})"
          puts "Please resolve rebase manually and rerun this script"
          exit
        end
      end
    end

    if blk
      # Save this as we descend into the tree
      grandParentBranchName = @parentBranchName

      @parentBranchName = branchName
      yield

      # Recover the previous parent if it exists
      if defined? grandParentBranchName
        @parentBranchName = grandParentBranchName
      # Otherwise, undefine the instance variable so we don't get confused
      else
        remove_instance_variable(:@parentBranchName)
      end
    else
      if defined? @allLeafBranches
        @allLeafBranches << branchName
      end
    end
  end

  # XXX This is not tested so it might cause irreparable damage and/or the end of the universe
  def aggregate(branchName, &blk)
    if defined? @allLeafBranches
      puts "Nesting aggregators is not supported"
      exit
    end

    # We have to delete the aggregator in case one of the descendants rewrote
    # its history, which would otherwise cause pandemonium.
    sh "git show-ref --verify --quiet refs/heads/#{branchName}" do |ok, res|
      puts "Deleting aggregator branch #{branchName}"
      if ok # This means the aggregator branch already exists
        sh "git branch -D #{branchName}" do |ok, res|
          if !ok
            puts "Delete of #{branchName} failed (status = #{res.exitstatus})"
            exit
          end

          sh "git branch #{branchName}" do |ok, res|
            if !ok
              puts "Create of new aggregator branch #{branchName} failed (status = #{res.exitstatus})"
              exit
            end
          end
        end
      end
    end

    @allLeafBranches = []

    yield

    sh "git checkout #{branchName}" do |ok, res|
      if !ok
        puts "Checkout of #{branchName} failed (status = #{res.exitstatus})"
        exit
      end

      sh "git merge #{@allLeafBranches.join(' ')}" do |ok, res|
       if !ok
         puts "Octopus merge of [ #{@allLeafBranches.join(', ')} ] into #{branchName} failed (status = #{res.exitstatus})"
         puts "Please resolve merge manually"
         exit
       end
      end
    end
  end
end