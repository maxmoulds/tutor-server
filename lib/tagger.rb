module Tagger
  BOOK_LOCATION_REGEX = /\A[\w-]+-ch(\d+)-s(\d+)/

  # If the tag string matches, it is considered to be of that type
  # This map is used to determine tag types for Exercises
  # Pages do not use this map (instead, they infer the tag type from where it appears in the page)
  # We do not automatically assign CC tags or else
  # they would match the section tags in non-CC books
  TAG_TYPE_REGEXES = HashWithIndifferentAccess.new({
    lo: /\A[\w-]+-lo\d+\z/,
    aplo: /\A[\w-]+-aplo-[\w-]+\z/,
    dok: /\Adok(\d+)\z/,
    blooms: /\Ablooms-(\d+)\z/,
    length: /\Atime-(\w+)\z/,
    teks: /\Aost-tag-teks-[\w-]+-(\w+)\z/
  })

  # The capture from the regex above is substituted into the template to form the tag name
  TAG_NAME_TEMPLATES = HashWithIndifferentAccess.new({
    dok: "DOK: %d",
    blooms: "Blooms: %d",
    length: "Length: %.1s"
  })

  def self.get_type(tag_string)
    TAG_TYPE_REGEXES.each{ |type, regex| return type.to_sym if regex.match(tag_string) }
    :generic
  end

  def self.get_data(type, tag_string)
    regex = TAG_TYPE_REGEXES[type]
    return if regex.nil?

    regex.match(tag_string).try(:[], 1)
  end

  def self.get_name(type, data)
    template = TAG_NAME_TEMPLATES[type]
    return if template.nil?

    template % data.capitalize
  end

  def self.get_hash(tag_string)
    type = get_type(tag_string)
    data = get_data(type, tag_string)
    name = get_name(type, data)
    {
      value: tag_string,
      name: name,
      type: type
    }
  end

  def self.get_book_location(value)
    matches = BOOK_LOCATION_REGEX.match(value)
    matches.nil? ? [] : [matches[1].to_i, matches[2].to_i]
  end
end
