# frozen_string_literal: true

module Ai
  class ServiceAccessToken < ApplicationRecord
    self.table_name = 'service_access_tokens'

    scope :expired, -> { where('expires_at < :now', now: Time.current) }
    scope :active, -> { where('expires_at > :now', now: Time.current) }

    attr_encrypted :token,
      mode: :per_attribute_iv,
      key: Settings.attr_encrypted_db_key_base_32,
      algorithm: 'aes-256-gcm',
      encode: false,
      encode_iv: false

    validates :token, :expires_at, presence: true
  end
end
