require 'rails_helper'

RSpec.describe Api::V1::ChapterTocRepresenter, type: :representer do
  let(:chapter) { { id: 1,
                    title: 'Good chapter',
                    type: 'foo',
                    book_location: [4, 1] } }

  subject(:represented) { described_class.new(Hashie::Mash.new(chapter)).to_hash }

  it 'sets the type to part' do
    expect(represented['type']).to eq('part')
  end

  it 'renames book_location to chapter_section' do
    expect(represented['chapter_section']).to eq([4, 1])
  end
end
