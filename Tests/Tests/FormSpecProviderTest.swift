//
//  FormSpecProviderTest.swift
//  StripeiOS Tests
//
//  Created by Yuki Tokuhiro on 3/7/22.
//  Copyright © 2022 Stripe, Inc. All rights reserved.
//

import XCTest
@_spi(STP) @testable import Stripe
@_spi(STP) @testable import StripeUICore

class FormSpecProviderTest: XCTestCase {
    func testLoadsJSON() throws {
        let e = expectation(description: "Loads form specs file")
        let sut = FormSpecProvider()
        sut.load { loaded in
            XCTAssertTrue(loaded)
            e.fulfill()
        }
        waitForExpectations(timeout: 2, handler: nil)
        
        guard let eps = sut.formSpec(for: "eps") else {
            XCTFail()
            return
        }
        XCTAssertEqual(eps.fields.count, 2)
        XCTAssertEqual(eps.fields.first, .name(FormSpec.NameFieldSpec(apiPath:nil, translationId: nil)))

        // ...and iDEAL has the correct dropdown spec
        guard let ideal = sut.formSpec(for: "ideal"),
              case .name = ideal.fields[0],
              case let .selector(selector) = ideal.fields[1] else {
                  XCTFail()
            return
        }
        XCTAssertEqual(selector.apiPath?["v1"], "ideal[bank]")
        XCTAssertEqual(selector.items.count, 13)
    }

    func testLoadJsonCanOverwriteLoadedSpecs() throws {
        let e = expectation(description: "Loads form specs file")
        let sut = FormSpecProvider()
        let paymentMethodType = "eps"
        sut.load { loaded in
            XCTAssertTrue(loaded)
            e.fulfill()
        }
        waitForExpectations(timeout: 2, handler: nil)
        guard let eps = sut.formSpec(for: paymentMethodType),
              eps.fields.count == 2,
              eps.fields.first == .name(FormSpec.NameFieldSpec(apiPath:nil, translationId: nil)) else {
            XCTFail()
            return
        }
        let updatedSpecJson =
        """
        [{
            "type": "eps",
            "async": false,
            "fields": [
                {
                    "type": "name",
                    "api_path": {
                        "v1": "billing_details[someOtherValue]"
                    }
                }
            ]
        }]
        """.data(using: .utf8)!
        let formSpec = try! JSONSerialization.jsonObject(with: updatedSpecJson) as! [NSDictionary]

        sut.load(from: formSpec)

        guard let epsUpdated = sut.formSpec(for: paymentMethodType),
              epsUpdated.fields.count == 1,
              epsUpdated.fields.first == .name(FormSpec.NameFieldSpec(apiPath:["v1":"billing_details[someOtherValue]"], translationId: nil)) else {
            XCTFail()
            return
        }
    }

    func testLoadJsonFailsGracefully() throws {
        let e = expectation(description: "Loads form specs file")
        let sut = FormSpecProvider()
        let paymentMethodType = "eps"
        sut.load { loaded in
            XCTAssertTrue(loaded)
            e.fulfill()
        }
        waitForExpectations(timeout: 2, handler: nil)
        guard let eps = sut.formSpec(for: paymentMethodType),
              eps.fields.count == 2,
              eps.fields.first == .name(FormSpec.NameFieldSpec(apiPath:nil, translationId: nil)) else {
            XCTFail()
            return
        }
        let updatedSpecJson =
        """
        [{
            "INVALID_type": "eps",
            "async": false,
            "fields": [
                {
                    "type": "name",
                    "api_path": {
                        "v1": "billing_details[someOtherValue]"
                    }
                }
            ]
        }]
        """.data(using: .utf8)!
        let formSpec = try! JSONSerialization.jsonObject(with: updatedSpecJson) as! [NSDictionary]

        sut.load(from: formSpec)

        guard let epsUpdated = sut.formSpec(for: paymentMethodType),
              epsUpdated.fields.count == 2,
              epsUpdated.fields.first == .name(FormSpec.NameFieldSpec(apiPath:nil, translationId: nil)) else {
            XCTFail()
            return
        }
    }

    func testLoadJsonDoesOverwrites() throws {
        let e = expectation(description: "Loads form specs file")
        let sut = FormSpecProvider()
        let paymentMethodType = "eps"
        sut.load { loaded in
            XCTAssertTrue(loaded)
            e.fulfill()
        }
        waitForExpectations(timeout: 2, handler: nil)
        guard let eps = sut.formSpec(for: paymentMethodType),
              eps.fields.count == 2,
              eps.fields.first == .name(FormSpec.NameFieldSpec(apiPath:nil, translationId: nil)),
              case .redirect_to_url = eps.nextActionSpec?.confirmResponseStatusSpecs["requires_action"]?.type,
              case .finished = eps.nextActionSpec?.postConfirmHandlingPiStatusSpecs?["succeeded"]?.type,
              case .canceled = eps.nextActionSpec?.postConfirmHandlingPiStatusSpecs?["requires_action"]?.type else {
                  XCTFail()
                  return
        }

        let updatedSpecJson =
        """
        [{
            "type": "eps",
            "async": false,
            "fields": [
                {
                    "type": "name",
                    "api_path": {
                        "v1": "billing_details[someOtherValue]"
                    }
                }
            ],
            "next_action_spec": {
                "confirm_response_status_specs": {
                    "requires_action": {
                        "type": "redirect_to_url"
                    }
                },
                "post_confirm_handling_pi_status_specs": {
                    "succeeded": {
                        "type": "finished"
                    },
                    "requires_action": {
                        "type": "finished"
                    }
                }
            }
        }]
        """.data(using: .utf8)!
        let formSpec = try! JSONSerialization.jsonObject(with: updatedSpecJson) as! [NSDictionary]

        sut.load(from: formSpec)

        // Validate ability to override LPM behavior of next actions
        guard let epsUpdated = sut.formSpec(for: paymentMethodType),
              epsUpdated.fields.count == 1,
              epsUpdated.fields.first == .name(FormSpec.NameFieldSpec(apiPath:["v1":"billing_details[someOtherValue]"], translationId: nil)),
              case .redirect_to_url = epsUpdated.nextActionSpec?.confirmResponseStatusSpecs["requires_action"]?.type,
              case .finished = epsUpdated.nextActionSpec?.postConfirmHandlingPiStatusSpecs?["succeeded"]?.type,
              case .finished = epsUpdated.nextActionSpec?.postConfirmHandlingPiStatusSpecs?["requires_action"]?.type else {
            XCTFail()
            return
        }
    }
    func testLoadJsonDoesOverwritesWithoutNextActionSpec() throws {
        let e = expectation(description: "Loads form specs file")
        let sut = FormSpecProvider()
        let paymentMethodType = "affirm"
        sut.load { loaded in
            XCTAssertTrue(loaded)
            e.fulfill()
        }
        waitForExpectations(timeout: 2, handler: nil)
        guard let affirm = sut.formSpec(for: paymentMethodType),
              affirm.fields.count == 1,
              affirm.fields.first == .affirm_header,
              case .redirect_to_url = affirm.nextActionSpec?.confirmResponseStatusSpecs["requires_action"]?.type,
              case .finished = affirm.nextActionSpec?.postConfirmHandlingPiStatusSpecs?["succeeded"]?.type,
              case .canceled = affirm.nextActionSpec?.postConfirmHandlingPiStatusSpecs?["requires_action"]?.type else {
            XCTFail()
            return
        }

        let updatedSpecJson =
        """
        [{
            "type": "affirm",
            "async": false,
            "fields": [
                {
                    "type": "name"
                }
            ]
        }]
        """.data(using: .utf8)!
        let formSpec = try! JSONSerialization.jsonObject(with: updatedSpecJson) as! [NSDictionary]

        sut.load(from: formSpec)

        guard let affirmUpdated = sut.formSpec(for: paymentMethodType),
              affirmUpdated.fields.count == 1,
              affirmUpdated.fields.first == .name(FormSpec.NameFieldSpec(apiPath: nil, translationId: nil)),
              affirmUpdated.nextActionSpec == nil else {
            XCTFail()
            return
        }
    }

    func testLoadJsonDoesNotOverwriteWhenWithUnsupportedNextAction() throws {
        let e = expectation(description: "Loads form specs file")
        let sut = FormSpecProvider()
        let paymentMethodType = "eps"
        sut.load { loaded in
            XCTAssertTrue(loaded)
            e.fulfill()
        }
        waitForExpectations(timeout: 2, handler: nil)
        guard let eps = sut.formSpec(for: paymentMethodType),
              eps.fields.count == 2,
              eps.fields.first == .name(FormSpec.NameFieldSpec(apiPath:nil, translationId: nil)),
              case .redirect_to_url = eps.nextActionSpec?.confirmResponseStatusSpecs["requires_action"]?.type,
              case .finished = eps.nextActionSpec?.postConfirmHandlingPiStatusSpecs?["succeeded"]?.type,
              case .canceled = eps.nextActionSpec?.postConfirmHandlingPiStatusSpecs?["requires_action"]?.type else {
            XCTFail()
            return
        }

        let updatedSpecJsonWithUnsupportedNextAction =
        """
        [{
            "type": "eps",
            "async": false,
            "fields": [
                {
                    "type": "name",
                    "api_path": {
                        "v1": "billing_details[someOtherValue]"
                    }
                }
            ],
            "next_action_spec": {
                "confirm_response_status_specs": {
                    "requires_action": {
                        "type": "redirect_to_url_v2_NotSupported"
                    }
                },
                "post_confirm_handling_pi_status_specs": {
                    "succeeded": {
                        "type": "finished"
                    },
                    "requires_action": {
                        "type": "canceled"
                    }
                }
            }
        }]
        """.data(using: .utf8)!
        let formSpec = try! JSONSerialization.jsonObject(with: updatedSpecJsonWithUnsupportedNextAction) as! [NSDictionary]
        sut.load(from: formSpec)

        // Validate that we were not able to override the spec read in from disk
        guard let epsUpdated = sut.formSpec(for: paymentMethodType),
              epsUpdated.fields.count == 2,
              epsUpdated.fields.first == .name(FormSpec.NameFieldSpec(apiPath:nil, translationId: nil)),
              case .redirect_to_url = epsUpdated.nextActionSpec?.confirmResponseStatusSpecs["requires_action"]?.type,
              case .finished = epsUpdated.nextActionSpec?.postConfirmHandlingPiStatusSpecs?["succeeded"]?.type,
              case .canceled = epsUpdated.nextActionSpec?.postConfirmHandlingPiStatusSpecs?["requires_action"]?.type else {
            XCTFail()
            return
        }
    }
    func testContainsKnownNextAction() throws {
        let formSpec =
        """
        [{
            "type": "eps",
            "async": false,
            "fields": [
            ],
            "next_action_spec": {
                "confirm_response_status_specs": {
                    "requires_action": {
                        "type": "redirect_to_url"
                    }
                },
                "post_confirm_handling_pi_status_specs": {
                    "succeeded": {
                        "type": "finished"
                    },
                    "requires_action": {
                        "type": "canceled"
                    }
                }
            }
        }]
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let decodedFormSpecs = try decoder.decode([FormSpec].self, from: formSpec)

        let sut = FormSpecProvider()
        XCTAssertFalse(sut.containsUnknownNextActions(formSpecs: decodedFormSpecs))
    }

    func testContainsUnknownNextAction_confirm() throws {
        let formSpec =
        """
        [{
            "type": "eps",
            "async": false,
            "fields": [
            ],
            "next_action_spec": {
                "confirm_response_status_specs": {
                    "requires_action": {
                        "type": "redirect_to_url_v2_NotSupported"
                    }
                },
                "post_confirm_handling_pi_status_specs": {
                    "succeeded": {
                        "type": "finished"
                    },
                    "requires_action": {
                        "type": "canceled"
                    }
                }
            }
        }]
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let decodedFormSpecs = try decoder.decode([FormSpec].self, from: formSpec)

        let sut = FormSpecProvider()
        XCTAssert(sut.containsUnknownNextActions(formSpecs: decodedFormSpecs))
    }

    func testContainsUnknownNextAction_PostConfirm() throws {
        let formSpec =
        """
        [{
            "type": "eps",
            "async": false,
            "fields": [
            ],
            "next_action_spec": {
                "confirm_response_status_specs": {
                    "requires_action": {
                        "type": "redirect_to_url"
                    }
                },
                "post_confirm_handling_pi_status_specs": {
                    "succeeded": {
                        "type": "finished_NotSupportedType"
                    },
                    "requires_action": {
                        "type": "canceled"
                    }
                }
            }
        }]
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let decodedFormSpecs = try decoder.decode([FormSpec].self, from: formSpec)

        let sut = FormSpecProvider()
        XCTAssert(sut.containsUnknownNextActions(formSpecs: decodedFormSpecs))
    }
}
