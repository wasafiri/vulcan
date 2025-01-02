class MedicalProvider < User
  # Medical Provider can see all constituents they certified
  has_many :applications, foreign_key: :medical_provider_id
  has_many :certified_constituents, class_name: "Constituent", foreign_key: :medical_provider_id
end
