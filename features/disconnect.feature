Feature: Disconnect
  As an MQTT client,
  I want to be able to disconnect cleanly

  Scenario: Disconnect message
    Given I have connected to the broker on port 1883
    When I send a DISCONNECT MQTT message
    Then the server should close the connection
