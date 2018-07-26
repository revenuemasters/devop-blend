
class IamInstanceProfile < CloudformationStack

  class << self

    def default_profile
      self.instance('default-iam-profile')
    end

  end

end
