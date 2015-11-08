# rubocop:disable Lint/HandleExceptions
module PageMagic
  describe Waiters do
    subject do
      Object.new.tap do |o|
        o.extend(described_class)
      end
    end

    let(:default_options) { { timeout_after: 0.1, retry_every: 0.05 } }

    it 'waits until the prescribed thing has happened' do
      expect { subject.wait_until(default_options) { true } }.to_not raise_exception
    end

    it 'should keep trying for a specified period' do
      start_time = Time.now

      begin
        subject.wait_until(default_options) { false }
      rescue TimeoutException
        #   This is expected
      end

      expect(Time.now - default_options[:timeout_after]).to be > start_time
    end

    context 'timeout_after specified' do
      it 'throws an exception if when the prescribed action does not happen in time' do
        expect { subject.wait_until(default_options) { false } }.to raise_error TimeoutException
      end
    end

    context 'retry time specified' do
      it 'retries at the given interval' do
        count = 0
        begin
          subject.wait_until(timeout_after: default_options[:timeout_after] * 2, retry_every: 0.1) do
            count += 1
          end
        rescue TimeoutException
          #   This is expected
        end
        expect(count).to eq(2)
      end
    end
  end
end
