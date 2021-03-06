describe Elasticity::PigStep do

  subject do
    Elasticity::PigStep.new('script.pig')
  end

  it { should be_a Elasticity::JobFlowStep }

  its(:name) { should == 'Elasticity Pig Step (script.pig)' }
  its(:script) { should == 'script.pig' }
  its(:variables) { should == { } }
  its(:action_on_failure) { should == 'TERMINATE_JOB_FLOW' }

  describe '#to_aws_step' do

    it 'should convert to aws step format' do
      step = subject.to_aws_step(Elasticity::JobFlow.new('access', 'secret'))
      step[:name].should == 'Elasticity Pig Step (script.pig)'
      step[:action_on_failure].should == 'TERMINATE_JOB_FLOW'
      step[:hadoop_jar_step][:jar].should == 's3://elasticmapreduce/libs/script-runner/script-runner.jar'
      step[:hadoop_jar_step][:args].should start_with([
        's3://elasticmapreduce/libs/pig/pig-script',
          '--run-pig-script',
          '--args',
          '-p'
      ])
      step[:hadoop_jar_step][:args][4] =~ /^E_PARALLELS=\d+$/
    end

    describe 'E_PARALLELS' do
      it 'should include the correct value of E_PARALLELS' do
        job_flow = Elasticity::JobFlow.new('access', 'secret')
        job_flow.instance_count = 8
        {
          '_' => 7,
          'm1.small' => 7,
          'm1.large' => 13,
          'c1.medium' => 13,
          'c1.xlarge' => 26
        }.each do |instance_type, value|
          job_flow.slave_instance_type = instance_type
          step = subject.to_aws_step(job_flow)
          step[:hadoop_jar_step][:args][4].should == "E_PARALLELS=#{value}"
        end
      end
    end

    context 'when variables are not provided' do
      let(:ps_with_no_variables) { Elasticity::PigStep.new('script.pig') }

      it 'should convert to aws step format' do
        step = ps_with_no_variables.to_aws_step(Elasticity::JobFlow.new('access', 'secret'))
        step[:hadoop_jar_step][:args][5].should == 'script.pig'
      end
    end

    context 'when variables are provided' do
      let(:ps_with_variables) do
        Elasticity::PigStep.new('script.pig').tap do |ps|
          ps.variables = {
            'VAR1' => 'VALUE1',
            'VAR2' => 'VALUE2'
          }
        end
      end

      it 'should convert to aws step format' do
        step = ps_with_variables.to_aws_step(Elasticity::JobFlow.new('access', 'secret'))
        step[:hadoop_jar_step][:args][3..9].should == [
          '-p', 'VAR1=VALUE1',
            '-p', 'VAR2=VALUE2',
            '-p', 'E_PARALLELS=1',
            'script.pig'
        ]
      end
    end

  end

  describe '.requires_installation?' do
    it 'should require installation' do
      Elasticity::PigStep.requires_installation?.should be_true
    end
  end

  describe '.aws_installation_step' do
    it 'should provide a means to install Pig' do
      Elasticity::PigStep.aws_installation_step.should == {
        :action_on_failure => 'TERMINATE_JOB_FLOW',
        :hadoop_jar_step => {
          :jar => 's3://elasticmapreduce/libs/script-runner/script-runner.jar',
          :args => [
            's3://elasticmapreduce/libs/pig/pig-script',
              '--base-path',
              's3://elasticmapreduce/libs/pig/',
              '--install-pig'
          ],
        },
        :name => 'Elasticity - Install Pig'
      }
    end
  end

end