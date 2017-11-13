require 'rails_helper'

RSpec.describe TrackTutorOnboardingEvent, type: :routine, vcr: VCR_OPTS do

  before(:all) do
    VCR.use_cassette('TrackTutorOnboardingEvent/sf_setup', VCR_OPTS) do
      @proxy = SalesforceProxy.new
      load_salesforce_user
      @proxy.ensure_schools_exist(["JP University"])
      @sf_contact_a = @proxy.new_contact
    end

    # To use placeholders for the user UUIDs, we have to set them up in a before(:all)
    # call, because `define_cassette_placeholder` doesn't work well from a before(:each)

    @user_no_sf = FactoryBot.create(:user)
    @user_sf_a = FactoryBot.create(:user, salesforce_contact_id: @sf_contact_a.id)

    VCR.configure do |config|
      config.define_cassette_placeholder("<USER_NO_SF_UUID>") { @user_no_sf.uuid }
      config.define_cassette_placeholder("<USER_SF_A_UUID>")  { @user_sf_a.uuid  }
    end
  end

  # We are reusing one SF contact and the two users so that we can correctly
  # put placeholders in for the user's UUIDs.  But each spec expects that
  # no TOAs have been created for the SF contact yet, so track which TOAs
  # we create and destroy them after each spec.

  before(:each) do
    @delete_me = []

    allow_any_instance_of(OpenStax::Salesforce::Remote::TutorOnboardingA).to receive(:create!).and_wrap_original do |m, *args|
      m.call(*args).tap{|object| @delete_me.push(object)}
    end
  end

  after(:each) do
    @delete_me.each{|obj| obj.destroy}
  end

  let(:anonymous_user) do
    profile = User::Models::AnonymousProfile.instance
    strategy = User::Strategies::Direct::AnonymousUser.new(profile)
    User::User.new(strategy: strategy)
  end

  let(:data) { {} }

  def call
    described_class[user: user, event: event, data: data].reload
  end

  def expect_call_to_set_timestamp(timestamp_field)
    time = Chronic.parse("July 23, 2017 5:04pm")
    Timecop.freeze(time) do
      toa = call
      expect(toa).to be_persisted
      expect(toa.send(timestamp_field)).to be_within(1.second).of(DateTime.parse(time.to_s))
    end
  end

  def expect_2nd_call_to_not_change_timestamp(timestamp_field)
    toa = call
    first_time = toa.send(timestamp_field)
    Timecop.freeze(5.minutes.from_now) do
      toa = call
      expect(toa.send(timestamp_field)).to be_within(1.seconds).of(first_time)
    end
  end

  def expect_2nd_call_to_change_timestamp(timestamp_field)
    toa = call
    first_time = toa.send(timestamp_field)
    Timecop.freeze(5.minutes.from_now) do
      toa = call
      expect(toa.send(timestamp_field)).to be_within(1.seconds).of(first_time + 5.minutes)
    end
  end

  context "when there is no SF user" do
    let(:event) { :like_preview_yes }
    let(:user) { @user_sf_a }

    it "freaks out in production" do
      clear_salesforce_user
      ActiveForce.clear_sfdc_client!
      expect{call}.to raise_error(OpenStax::Salesforce::UserMissing)
    end
  end

  context 'when user anonymous and no pardot contact ID supplied' do
    let(:event) { :arrived_my_courses }
    let(:user) { anonymous_user }

    it 'raises an error' do
      expect{call}.to raise_error(TrackTutorOnboardingEvent::CannotGetToa)
    end
  end

  context 'arrive to marketing page from pardot' do
    let(:event) { :arrived_tutor_marketing_page_from_pardot }
    let(:data) {{
      pardot_reported_contact_id: @sf_contact_a.id,
      pardot_reported_piaid: "piaid",
      pardot_reported_picid: "picid"
    }}

    context 'missing data' do
      let(:user) { "whatever" }

      it 'requires pardot_reported_contact_id' do
        data[:pardot_reported_contact_id] = ""
        expect{call}.to raise_error(TrackTutorOnboardingEvent::MissingArgument,
                                    /pardot_reported_contact_id.*arrived_tutor_marketing_page_from_pardot/)
      end

      it 'requires pardot_reported_piaid' do
        data.delete(:pardot_reported_piaid)
        expect{call}.to raise_error(TrackTutorOnboardingEvent::MissingArgument,
                                    /pardot_reported_piaid.*arrived_tutor_marketing_page_from_pardot/)
      end

      it 'requires pardot_reported_picid' do
        data.delete(:pardot_reported_picid)
        expect{call}.to raise_error(TrackTutorOnboardingEvent::MissingArgument,
                                    /pardot_reported_picid.*arrived_tutor_marketing_page_from_pardot/)
      end
    end

    context 'anonymous user' do
      let(:user) { anonymous_user }

      it 'creates the TOA based on the pardot contact ID' do
        toa = call
        expect(toa.id).to be_present
        expect(toa.pardot_reported_contact_id).to eq @sf_contact_a.id
      end
    end

    context 'signed in' do
      context 'has salesforce contact ID' do
        let(:user) { @user_sf_a }

        it 'picks up the TOA by that SF ID' do
          existing_toa = @proxy.new_tutor_onboarding_a(first_teacher_contact_id: @sf_contact_a.id)
          toa = call
          expect(toa.id).to eq existing_toa.id
          expect(toa.pardot_reported_contact_id).to eq @sf_contact_a.id
          expect(toa.accounts_uuid).to eq @user_sf_a.uuid
        end

        it 'sets the timestamp' do
          expect_call_to_set_timestamp(:arrived_marketing_page_from_pardot_at)
        end

        it 'does not overwrite the timestamp on 2nd arrival' do
          expect_2nd_call_to_not_change_timestamp(:arrived_marketing_page_from_pardot_at)
        end
      end

      context 'no salesforce contact ID' do
        let(:user) { @user_no_sf }

        it 'picks up the TOA by the pardot SF ID' do
          existing_toa = @proxy.new_tutor_onboarding_a(pardot_reported_contact_id: @sf_contact_a.id)
          toa = call
          expect(toa.id).to eq existing_toa.id
          expect(toa.pardot_reported_contact_id).to eq @sf_contact_a.id
          expect(toa.first_teacher_contact_id).to be_blank
          expect(toa.accounts_uuid).to eq @user_no_sf.uuid
        end
      end
    end

    context 'teacher 1 forwards email to teacher 2 who uses same link' do
      xit 'does not reuse teacher 1\'s TOA' do

      end

      # TODO do all cases of signed in and not signed in?
    end

    context '2nd arrival from same user' do
      xit 'does not overwrite the first timestamp' do

      end
    end
  end

  context 'arrived marketing page not from pardot' do
    let(:event) { :arrived_tutor_marketing_page_not_from_pardot }
    let(:user) { @user_sf_a }

    context 'signed in but no SF contact ID' do
      it 'sets the timestamp' do
        expect_call_to_set_timestamp(:arrived_marketing_page_not_from_pardot_at)
      end

      it 'does not overwrite the timestamp on 2nd arrival' do
        expect_2nd_call_to_not_change_timestamp(:arrived_marketing_page_not_from_pardot_at)
      end
    end

  end

  context 'created preview' do
    let(:event) { :created_preview_course }
    let(:user) { @user_sf_a }

    it 'sets preview_created_at' do
      expect_call_to_set_timestamp(:preview_created_at)
    end

    it 'does not change preview_created_at for 2nd time' do
      expect_2nd_call_to_not_change_timestamp(:preview_created_at)
    end
  end

  context 'created real course' do
    let(:event) { :created_real_course }
    let(:user) { @user_sf_a }

    it 'sets real_course_created_at' do
      expect_call_to_set_timestamp(:real_course_created_at)
    end

    it 'does not change real_course_created_at for 2nd time' do
      expect_2nd_call_to_not_change_timestamp(:real_course_created_at)
    end
  end

  context 'ask later about like preview' do
    let(:event) { :like_preview_ask_later }
    let(:user) { @user_sf_a }

    it 'updates the count' do
      toa = call
      expect(toa.like_preview_ask_later_count).to eq 1

      toa = call
      expect(toa.like_preview_ask_later_count).to eq 2
    end
  end

  context 'say yes to like preview' do
    let(:event) { :like_preview_yes }
    let(:user) { @user_sf_a }

    it 'sets like_preview_yes' do
      expect_call_to_set_timestamp(:like_preview_yes_at)
    end

    it 'does not change like_preview_yes for 2nd preview' do
      expect_2nd_call_to_not_change_timestamp(:like_preview_yes_at)
    end
  end

  context 'adoption decision' do
    let(:event) { :made_adoption_decision }
    let(:user) { @user_sf_a }
    let(:data) {{
      decision: "For course credit"
    }}

    it "errors if data missing" do
      data[:decision] = ""
      expect{call}.to raise_error(TrackTutorOnboardingEvent::MissingArgument)
    end

    it 'saves the timestamp' do
      expect_call_to_set_timestamp(:latest_adoption_decision_at)
    end

    it 'saves the decision' do
      toa = call
      expect(toa.latest_adoption_decision).to eq "For course credit"
    end

    it 'overwrites the first timestamp if done again' do
      expect_2nd_call_to_change_timestamp(:latest_adoption_decision_at)
    end

    it 'overwrites the first decision if done again' do
      toa = call
      data[:decision] = "For extra credit"
      toa = call
      expect(toa.latest_adoption_decision).to eq "For extra credit"
    end
  end

  context "when event unknown" do
    let(:event) { :booyah }
    let(:user) { @user_sf_a }

    it 'raise an exception' do
      expect{call}.to raise_error(StandardError)
    end
  end

  context 'when run in background' do
    def expect_instant_background_failure(exception_class, &block)
      Delayed::Worker.with_delay_jobs(true) do
        expect_any_instance_of(exception_class).to receive(
          :instantly_fail_if_in_background_job?
        ).and_call_original
        expect_any_instance_of(Delayed::Job).to receive(:fail!).and_call_original
        block.call
        expect(Delayed::Worker.new.work_off).to eq [0,1]
      end
    end

    it 'fails instantly for an unknown event' do
      expect_instant_background_failure(TrackTutorOnboardingEvent::InstantFailStandardError) {
        described_class.perform_later(user: "whatever", event: "wowzer")
      }
    end

    it 'fails instantly for missing arguments' do
      expect_instant_background_failure(TrackTutorOnboardingEvent::MissingArgument) {
        described_class.perform_later(user: "whatever", event: "made_adoption_decision")
      }
    end

    it 'fails instantly when cannot get TOA' do
      expect_instant_background_failure(TrackTutorOnboardingEvent::CannotGetToa) {
        described_class.perform_later(user: anonymous_user, event: "arrived_my_courses")
      }
    end

    it 'retries if there are SF errors on save' do
      Delayed::Worker.with_delay_jobs(true) do
        # Stub the `errors` call in the track routine to return true so we simulate a SF error
        errors_call_count = 0
        allow_any_instance_of(
          OpenStax::Salesforce::Remote::TutorOnboardingA
        ).to receive(:errors).and_wrap_original { |m, *args|
          errors_call_count += 1
          3 == errors_call_count ? ["blah"] : m.call(*args)
        }

        described_class.perform_later(user: @user_sf_a, event: "like_preview_yes")

        expect_any_instance_of(Delayed::Job).not_to receive(:fail!)
        s,f = Delayed::Worker.new.work_off(1)
        expect(Delayed::Job.first.attempts).to eq 1
        expect(Delayed::Job.first.failed_at).to be_nil
      end
    end

  end


end
