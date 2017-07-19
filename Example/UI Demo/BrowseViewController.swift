//
//  BrowseViewController.swift
//  UI Demo
//
//  Created by Ben Guo on 7/18/17.
//  Copyright © 2017 Stripe. All rights reserved.
//

import UIKit
import Stripe

class BrowseViewController: UITableViewController, STPPaymentMethodsViewControllerDelegate {

    enum Demo: String {
        static let count = 5
        case STPPaymentCardTextField = "Card Field"
        case STPAddCardViewController = "Add Card Form"
        case STPPaymentMethodsViewController = "Payment Methods Page"
        case STPShippingInfoViewController = "Shipping Form"
        case ApplePay = "Apple Pay"

        init?(row: Int) {
            switch row {
            case 0: self = .STPPaymentCardTextField
            case 1: self = .STPAddCardViewController
            case 2: self = .STPPaymentMethodsViewController
            case 3: self = .STPShippingInfoViewController
            case 4: self = .ApplePay
            default: return nil
            }
        }
    }

    let customerContext = MockCustomerContext()
    let configuration = STPPaymentConfiguration.shared()
    let theme = STPTheme.default()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "UI Sampler"
        self.tableView.tableFooterView = UIView()

        self.configuration.requiredShippingAddressFields = [.postalAddress, .phone]
        self.configuration.shippingType = .shipping
    }

    // MARK: UITableViewDelegate

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Demo.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        if let example = Demo(row: indexPath.row) {
            cell.textLabel?.text = example.rawValue
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let example = Demo(row: indexPath.row) else { return }

        switch example {
        case .STPPaymentCardTextField: return
        case .STPAddCardViewController: return
        case .STPPaymentMethodsViewController:
            let config = STPPaymentConfiguration()
            config.additionalPaymentMethods = []
            config.requiredBillingAddressFields = .none
            let theme = STPTheme.default()
            let viewController = STPPaymentMethodsViewController(configuration: config,
                                                                 theme: theme,
                                                                 customerContext: self.customerContext,
                                                                 delegate: self)
            let navigationController = UINavigationController(rootViewController: viewController)
            self.present(navigationController, animated: true, completion: nil)
        case .STPShippingInfoViewController:
            return
//            self.paymentContext?.presentShippingViewController()
        case .ApplePay: return
        }
    }

    // MARK: STPPaymentMethodsViewControllerDelegate

    func paymentMethodsViewControllerDidCancel(_ paymentMethodsViewController: STPPaymentMethodsViewController) {
        self.dismiss(animated: true, completion: nil)
    }

    func paymentMethodsViewControllerDidFinish(_ paymentMethodsViewController: STPPaymentMethodsViewController) {
        paymentMethodsViewController.navigationController?.popViewController(animated: true)
//        self.dismiss(animated: true, completion: nil)
    }

    func paymentMethodsViewController(_ paymentMethodsViewController: STPPaymentMethodsViewController, didFailToLoadWithError error: Error) {
        self.dismiss(animated: true, completion: nil)
    }

    // MARK: STPPaymentContextDelegate

    func paymentContext(_ paymentContext: STPPaymentContext, didUpdateShippingAddress address: STPAddress, completion: @escaping STPShippingMethodsCompletionBlock) {
        let upsGround = PKShippingMethod()
        upsGround.amount = 0
        upsGround.label = "UPS Ground"
        upsGround.detail = "Arrives in 3-5 days"
        upsGround.identifier = "ups_ground"
        let upsWorldwide = PKShippingMethod()
        upsWorldwide.amount = 10.99
        upsWorldwide.label = "UPS Worldwide Express"
        upsWorldwide.detail = "Arrives in 1-3 days"
        upsWorldwide.identifier = "ups_worldwide"
        let fedEx = PKShippingMethod()
        fedEx.amount = 5.99
        fedEx.label = "FedEx"
        fedEx.detail = "Arrives tomorrow"
        fedEx.identifier = "fedex"

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if address.country == nil || address.country == "US" {
                completion(.valid, nil, [upsGround, fedEx], fedEx)
            }
            else if address.country == "AQ" {
                let error = NSError(domain: "ShippingError", code: 123, userInfo: [NSLocalizedDescriptionKey: "Invalid Shipping Address",
                                                                                   NSLocalizedFailureReasonErrorKey: "We can't ship to this country."])
                completion(.invalid, error, nil, nil)
            }
            else {
                fedEx.amount = 20.99
                completion(.valid, nil, [upsWorldwide, fedEx], fedEx)
            }
        }
    }


}

