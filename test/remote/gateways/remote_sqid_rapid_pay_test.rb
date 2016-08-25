require "test_helper"
require 'digest'

class SqidRapidPayGatewayTest < Test::Unit::TestCase
  include CommStub

  def setup
    # ActiveMerchant::Billing::SqidRapidPayGateway.partner_id = nil
    @gateway = SqidRapidPayGateway.new(fixtures(:sqid_rapid_pay))

    @credit_card = credit_card('5163200000000008', verification_value: '070', year:2020, month: 8)
    @amount = 100
    address = address(suburb: 'Ashgrove', country: 'AUS', postcode: '4005',state: 'QLD')
    @purchase_options = {
        billing_address: address, order_id: 54321,
        email: 'geoffreyd@gmail.com'
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @purchase_options
    )

    assert_success response
    assert_equal 'Honour with identification', response.message
    assert response.test?
  end

  def test_invalid_login
    gateway = SqidRapidPayGateway.new(login: 'NonExistantUser', api_key: 'invalidKey', pass_phrase: 'wrong')
    response = gateway.purchase(@amount, @credit_card, @purchase_options)

    assert_failure response
    assert_equal 'Invalid Merchant details', response.message
  end

  def test_expired_card
    @credit_card.year = Date.today.year - 1
    response = @gateway.purchase(@amount, @credit_card, @purchase_options
    )

    assert_failure response
    assert_equal 'Invalid expiry', response.message
  end

  def test_invalid_funds
    card = credit_card('4564710000000020', year: 2020, month: 5, verification_value: 234)
    response = @gateway.purchase(@amount, card, @purchase_options)

    assert_failure response
    assert_equal 'Not sufficient funds', response.message
  end

  private

  # def successful_purchase_response(options = {})
  #   verification_status = options[:verification_status] || 0
  #   verification_status = %Q{"#{verification_status}"} if verification_status.is_a? String
  #   %(
  #     {
  #       "providerCode": "730851557",
  #       "providerMessage": "Honour with identification",
  #       "providerResponseCode": "8",
  #       "sqidResponseCode": 0,
  #       "sqidResponseMessage": "Approved",
  #       "transactionID": "fa6c05ba-1471-45c5-8a8e-76becdf858e3",
  #       "receiptNo": "27470",
  #       "custom1": "",
  #       "custom2": "",
  #       "custom3": "",
  #       "hashValue": "8aa9955521f09cb1b129a1f4218c6fa1"
  #     }
  #   )
  # end

end
