class Content::Models::Tag < Tutor::SubSystems::BaseModel
  has_many :page_tags, dependent: :destroy
  has_many :exercise_tags, dependent: :destroy
  has_many :lo_teks_tags, foreign_key: :lo_id, dependent: :destroy
  has_many :teks_tags, through: :lo_teks_tags, class_name: 'Tag', source: :teks

  # List the different types of tags
  enum tag_type: [ :generic, :teks, :lo ]

  validates :value, presence: true
  validates :tag_type, presence: true

  def chapter_section
    matches = /-ch(\d+)-s(\d+)-lo\d+$/.match(value)
    "#{matches[1].to_i}.#{matches[2].to_i}" unless matches.nil?
  end
end
