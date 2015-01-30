require File.join(File.dirname(__FILE__), 'git-propagate')

include GitPropagate

branch 'master' do
  aggregate 'totality' do
    branch 'sub' do
      branch 'sub-sub'
    end

    branch 'other'
  end
end
