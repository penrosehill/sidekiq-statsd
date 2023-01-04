require "spec_helper"

describe Sidekiq::Statsd::ServerMiddleware do
  subject(:middleware) { described_class.new(statsd: client) }

  let(:worker) { double "Dummy worker" }
  let(:msg)    { { 'queue' => 'mailer' } }
  let(:queue)  { nil }
  let(:client) { double('StatsD').as_null_object }

  let(:worker_name) { worker.class.name.gsub("::", ".") }

  let(:clean_job)  { ->{} }
  let(:broken_job) { ->{ raise 'error' } }

  before do
    allow(client).to receive(:batch).and_yield(client)
  end

  it "raises error if no statsd supplied" do
    expect { described_class.new }.to raise_error("A StatsD client must be provided")
  end

  context "with customised options" do
    describe "#new" do
      it "uses the custom metric name prefix options" do
        expect(client)
          .to receive(:time)
          .with("application.sidekiq.#{worker_name}.processing_time")
          .once
          .and_yield

        described_class
          .new(statsd: client, prefix: 'application.sidekiq', worker_stats: true)
          .call(worker, msg, queue, &clean_job)
      end
    end
  end

  context 'without global sidekiq stats' do
    it "doesn't initialize a Sidekiq::Stats instance" do
      # Sidekiq::Stats.new makes redis calls
      expect(Sidekiq::Stats).not_to receive(:new)
      described_class.new(statsd: client, sidekiq_stats: false)
    end

    it "doesn't initialize a Sidekiq::Workers instance" do
      # Sidekiq::Workers.new makes redis calls
      expect(Sidekiq::Workers).not_to receive(:new)
      described_class.new(statsd: client, sidekiq_stats: false)
    end
  end

  context "with failed execution" do
    let(:job) { broken_job }

    describe "#call" do
      before do
        allow(client)
          .to receive(:time)
          .with("sidekiq.#{worker_name}.processing_time")
          .and_yield
      end
    end

    it_behaves_like "a resilient gauge reporter"
  end
end
