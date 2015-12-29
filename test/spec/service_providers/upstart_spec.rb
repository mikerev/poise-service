#
# Copyright 2015, Noah Kantrowitz
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'spec_helper'

describe PoiseService::ServiceProviders::Upstart do
  describe '#action_enable' do
    service_provider('upstart')
    step_into(:poise_service)
    let(:upstart_version) { '0' }
    before do
      allow_any_instance_of(described_class).to receive(:upstart_version).and_return(upstart_version)
    end
    recipe do
      poise_service 'test' do
        command 'myapp --serve'
      end
    end

    context 'with upstart 0.6.5' do
      let(:upstart_version) { '0.6.5' }
      it { is_expected.to render_file('/etc/init/test.conf').with_content(<<-EOS) }
# test generated by poise-service for poise_service[test]

description "test"

start on runlevel [2345]
stop on runlevel [!2345]

respawn
respawn limit 10 5
umask 022
chdir /

script
exec /opt/chef/embedded/bin/ruby <<EOH
require 'etc'
ent = Etc.getpwnam("root")
if Process.euid != ent.uid || Process.egid != ent.gid
  Process.initgroups(ent.name, ent.gid)
  Process::GID.change_privilege(ent.gid) if Process.egid != ent.gid
  Process::UID.change_privilege(ent.uid) if Process.euid != ent.uid
end
ENV["HOME"] = Dir.home("root") rescue nil
exec(*["myapp", "--serve"])
EOH
end script
EOS

      context 'with a stop signal' do
        recipe do
          poise_service 'test' do
            command 'myapp --serve'
            stop_signal 'KILL'
          end
        end

        it { is_expected.to render_file('/etc/init/test.conf').with_content(<<-EOS) }
# test generated by poise-service for poise_service[test]

description "test"

start on runlevel [2345]
stop on runlevel [!2345]

respawn
respawn limit 10 5
umask 022
chdir /

script
exec /opt/chef/embedded/bin/ruby <<EOH
require 'etc'
ent = Etc.getpwnam("root")
if Process.euid != ent.uid || Process.egid != ent.gid
  Process.initgroups(ent.name, ent.gid)
  Process::GID.change_privilege(ent.gid) if Process.egid != ent.gid
  Process::UID.change_privilege(ent.uid) if Process.euid != ent.uid
end
ENV["HOME"] = Dir.home("root") rescue nil
exec(*["myapp", "--serve"])
EOH
end script
pre-stop script
  PID=`initctl status test | sed 's/^.*process \\([0-9]*\\)$/\\1/'`
  if [ -n "$PID" ]; then
    kill -KILL "$PID"
  fi
end script
EOS
      end # /context with a stop signal
    end # /context with upstart 0.6.5

    context 'with upstart 1.5' do
      let(:upstart_version) { '1.5' }
      it { is_expected.to render_file('/etc/init/test.conf').with_content(<<-EOH) }
# test generated by poise-service for poise_service[test]

description "test"

start on runlevel [2345]
stop on runlevel [!2345]

respawn
respawn limit 10 5
umask 022
chdir /
setuid root
kill signal TERM

exec myapp --serve
EOH

      context 'with a reload signal' do
        recipe do
          poise_service 'test' do
            command 'myapp --serve'
            reload_signal 'USR1'
          end
        end

        it { expect { subject }.to raise_error PoiseService::Error }
      end # /context with a reload signal
    end # /context with upstart 1.5

    context 'with upstart 1.12.1' do
      let(:upstart_version) { '1.12.1' }
      it { is_expected.to render_file('/etc/init/test.conf').with_content(<<-EOH) }
# test generated by poise-service for poise_service[test]

description "test"

start on runlevel [2345]
stop on runlevel [!2345]

respawn
respawn limit 10 5
umask 022
chdir /
setuid root
kill signal TERM
reload signal HUP

exec myapp --serve
EOH
    end # /context with upstart 1.12.1
  end # /describe #action_enable

  describe '#action_disable' do
    service_provider('upstart')
    step_into(:poise_service)
    recipe do
      poise_service 'test' do
        action :disable
      end
    end

    it { is_expected.to delete_file('/etc/init/test.conf') }
  end # /describe #action_disable

  describe '#action_reload' do
    service_provider('upstart')
    step_into(:poise_service)
    let(:upstart_version) { '0' }
    before do
      allow_any_instance_of(described_class).to receive(:upstart_version).and_return(upstart_version)
    end

    context 'with upstart 1.5' do
      let(:upstart_version) { '1.5' }

      context 'with a reload signal' do
        recipe do
          poise_service 'test' do
            action :reload
            command 'myapp --serve'
            reload_signal 'USR1'
          end
        end

        it { expect { subject }.to raise_error PoiseService::Error }
      end # /context with a reload signal

      context 'with a reload signal and reload_shim:true' do
        recipe do
          poise_service 'test' do
            action :reload
            command 'myapp --serve'
            reload_signal 'USR1'
            options :upstart, reload_shim: true
          end
        end

        it do
          expect_any_instance_of(described_class).to receive(:pid).and_return(123)
          expect(Process).to receive(:kill).with('USR1', 123)
          run_chef
        end
      end # /context with a reload signal and reload_shim:true
    end # /context with upstart 1.5

    context 'with upstart 1.12.1' do
      let(:upstart_version) { '1.12.1' }

      context 'with a reload signal' do
        recipe do
          poise_service 'test' do
            action :reload
            command 'myapp --serve'
            reload_signal 'USR1'
          end
        end

        it do
          fake_service = double('service_resource', updated_by_last_action: nil, updated_by_last_action?: false)
          expect(fake_service).to receive(:run_action).with(:reload)
          expect_any_instance_of(described_class).to receive(:service_resource).at_least(:once).and_return(fake_service)
          run_chef
        end
      end # /context with a reload signal
    end # /context with upstart 1.12.1
  end # /describe #action_reload

  describe '#upstart_version' do
    subject { described_class.new(nil, nil).send(:upstart_version) }
    context 'with version 1.12.1' do
      before do
        fake_cmd = double('shellout', error?: false, live_stream: true, run_command: true, stdout: <<-EOH)
init (upstart 1.12.1)
Copyright (C) 2006-2014 Canonical Ltd., 2011 Scott James Remnant

This is free software; see the source for copying conditions.  There is NO warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
EOH
        expect(Mixlib::ShellOut).to receive(:new).with(%w{initctl --version}, kind_of(Hash)).and_return(fake_cmd)
      end
      it { is_expected.to eq '1.12.1' }
    end # /context with version 1.12.1

    context 'with an error' do
      before do
        fake_cmd = double('shellout', error?: true, live_stream: true, run_command: true)
        expect(Mixlib::ShellOut).to receive(:new).with(%w{initctl --version}, kind_of(Hash)).and_return(fake_cmd)
      end
      it { is_expected.to eq '0' }
    end # /context with an error
  end # /describe #upstart_version

  describe '#upstart_features' do
    subject do
      provider = described_class.new(nil, nil)
      expect(provider).to receive(:upstart_version).and_return(upstart_version)
      provider.send(:upstart_features)
    end

    context 'with upstart 0' do
      let(:upstart_version) { '0' }
      it { is_expected.to eq({kill_signal: false, reload_signal: false, setuid: false}) }
    end # /context with upstart 0

    # RHEL 6
    context 'with upstart 0.6.5' do
      let(:upstart_version) { '0.6.5' }
      it { is_expected.to eq({kill_signal: false, reload_signal: false, setuid: false}) }
    end # /context with upstart 0.6.5

    # Ubuntu 12.04
    context 'with upstart 1.5' do
      let(:upstart_version) { '1.5' }
      it { is_expected.to eq({kill_signal: true, reload_signal: false, setuid: true}) }
    end # /context with upstart 1.5

    # Ubuntu 14.04
    context 'with upstart 1.12.1' do
      let(:upstart_version) { '1.12.1' }
      it { is_expected.to eq({kill_signal: true, reload_signal: true, setuid: true}) }
    end # /context with upstart 1.12.1
  end # /describe #upstart_features

  describe '#pid' do
    context 'service is running' do
      before do
        fake_cmd = double('shellout', error?: false, live_stream: true, run_command: nil, stdout: <<-EOH)
test start/running, process 2132
EOH
        expect(Mixlib::ShellOut).to receive(:new).with(%w{initctl status test}, kind_of(Hash)).and_return(fake_cmd)
      end
      subject { described_class.new(double(service_name: 'test'), nil) }
      its(:pid) { is_expected.to eq 2132 }
    end # context service is running

    context 'service is stopped' do
      before do
        fake_cmd = double('shellout', error?: false, live_stream: true, run_command: nil, stdout: <<-EOH)
test stop/waiting
EOH
        expect(Mixlib::ShellOut).to receive(:new).with(%w{initctl status test}, kind_of(Hash)).and_return(fake_cmd)
      end
      subject { described_class.new(double(service_name: 'test'), nil) }
      its(:pid) { is_expected.to be_nil }
    end # context service is stopped

    context 'initctl errors' do
      before do
        fake_cmd = double('shellout', error?: true, live_stream: true, run_command: nil)
        expect(Mixlib::ShellOut).to receive(:new).with(%w{initctl status test}, kind_of(Hash)).and_return(fake_cmd)
      end
      subject { described_class.new(double(service_name: 'test'), nil) }
      its(:pid) { is_expected.to be_nil }
    end # context initctl errors
  end # /describe #pid
end
