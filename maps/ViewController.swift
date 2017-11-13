//
//  ViewController.swift
//  maps
//
//  Created by McCabe Tonna on 11/10/17.
//  Copyright © 2017 Wambl, LLC. All rights reserved.
//

import UIKit
import GooglePlacePicker
import SnapKit
import CoreLocation
import Alamofire
import SwiftyJSON

class ViewController: UIViewController {
    
    var current_location: CLLocation?

    lazy var locationManager: CLLocationManager = {
        let a = CLLocationManager()
        a.delegate = self
        return a
    }()
    
    lazy var placesClient: GMSPlacesClient = {
        let a = GMSPlacesClient.shared()
        return a
    }()
    
    lazy var loader: UIActivityIndicatorView = {
        let a = UIActivityIndicatorView(activityIndicatorStyle: .gray)
        a.hidesWhenStopped = true
        return a
    }()
    
    var tv: UIView?
    var loading: Bool = false {
        
        didSet {
            
            if loading {
                loader.startAnimating()
                tv = navigationItem.titleView
                navigationItem.titleView = loader
            } else {
                loader.stopAnimating()
                navigationItem.titleView = tv
            }
            
        }
        
    }
    
    var waitingForLocation: Bool = false {
        
        didSet {
            
            if waitingForLocation { locationManager.startUpdatingLocation() }
            if !waitingForLocation { locationManager.stopUpdatingLocation() }
            
        }
        
    }
    
    lazy var optimizeButton: UIButton = {
        let a = UIButton(type: .system)
        a.setTitle("OPTIMIZE ROUTE", for: .normal)
        a.backgroundColor = UIColor.blue
        a.tintColor = UIColor.white
        a.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        a.isEnabled = false
        a.addTarget(self, action: #selector(optimizeTapped), for: .touchUpInside)
        return a
    }()
    @objc func optimizeTapped(){
        
        guard optimizeButton.titleLabel?.text == "START ROUTE" else {
            
            openMaps()
            return
            
        }
        
        waitingForLocation = true
        loading = true
        
    }
    
    lazy var addButton: UIBarButtonItem = {
        let a = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addPressed))
        return a
    }()
    @objc func addPressed(){
        
        let config = GMSPlacePickerConfig(viewport: nil)
        let placePicker = GMSPlacePickerViewController(config: config)
        placePicker.delegate = self
        
        present(placePicker, animated: true, completion: nil)
        
    }
    
    var places: [GMSPlace] = [] {
        
        didSet {
            
            optimizeButton.isEnabled = places.count > 0
            
        }
        
    }
    
    lazy var table: UITableView = {
        let a = UITableView()
        a.register(UITableViewCell.classForCoder(), forCellReuseIdentifier: "Cell")
        a.delegate = self
        a.dataSource = self
        return a
    }()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.title = "Add Location"
        navigationItem.setRightBarButton(addButton, animated: false)
        
        view.addSubview(optimizeButton)
        optimizeButton.snp.makeConstraints { m in
            m.leading.bottom.trailing.equalTo(view)
            m.height.equalTo(60)
        }
        
        view.addSubview(table)
        table.snp.makeConstraints { m in
            m.top.leading.trailing.equalTo(view)
            m.bottom.equalTo(optimizeButton.snp.top)
        }
        
        locationManager.requestWhenInUseAuthorization()
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func optimizeRoute(){
        
        guard let _location = current_location else { return }
        
        print("Optimize Route",Date())
        
        let origin = "\(_location.coordinate.latitude),\(_location.coordinate.longitude)"
        
        var waypoints = places.map { place in
            
            return "place_id:" + place.placeID
            
        }
        waypoints.insert("optimize:true", at: 0)
        
        let waypointsString = waypoints.joined(separator: "|").addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
        
        let path = "https://maps.googleapis.com/maps/api/directions/json?origin=\(origin)&destination=\(origin)&waypoints=\(waypointsString)&key=\(Config.api_key)"
        
        Alamofire.request(path).validate().responseJSON { response in
            
            switch response.result {
            case .success:
                
                let _json = JSON(response.result.value!)
                
                if let a = _json["geocoded_waypoints"].array {

                    let optimized_places = a.map { $0["place_id"].string! }
                    
                    var new_places: [(place: GMSPlace,i: Int)] = []
                    
                    for place in self.places {
                        
                        if let i = optimized_places.index(of: place.placeID) { new_places.append((place: place, i: i)) }
                        
                    }
                    
                    new_places.sort { $0.i < $1.i }
                    
                    self.places = new_places.map { $0.place }
                    self.table.reloadData()
                    
                    self.optimizeButton.setTitle("START ROUTE", for: .normal)
                   
                }
                
            case .failure(let error):
                
                print("!!! Directions API Error !!!")
                print(error)
                print(error.localizedDescription)
                
            }
            
            self.loading = false
            
        }
        
    }

    func openMaps(){
        
        guard let _location = current_location else { return }
        
        var open_urls = self.places.map { place in
            
            return "\(place.coordinate.latitude),\(place.coordinate.longitude)"
            
        }
        
        open_urls.insert("\(_location.coordinate.latitude),\(_location.coordinate.longitude)", at: 0)
        open_urls.append("\(_location.coordinate.latitude),\(_location.coordinate.longitude)")
        
        UIApplication.shared.openURL(URL(string:"comgooglemapsurl://www.google.com/maps/dir/" + open_urls.joined(separator: "/"))!)

        
    }
    
}

extension ViewController: GMSPlacePickerViewControllerDelegate {
    
    func placePicker(_ viewController: GMSPlacePickerViewController, didPick place: GMSPlace) {
        
        table.beginUpdates()
        let ip = IndexPath(row: places.count, section: 0)
        places.append(place)
        table.insertRows(at: [ip], with: .automatic)
        table.endUpdates()
        
        viewController.dismiss(animated: true, completion: nil)
        
    }
    
    func placePickerDidCancel(_ viewController: GMSPlacePickerViewController) {
        
        viewController.dismiss(animated: true, completion: nil)
        
    }
    
}

extension ViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return places.count
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell")!
        
        let place = places[indexPath.row]
        
        cell.textLabel?.text = place.name
        
        return cell
        
    }
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        
        if editingStyle == .delete {
            
            tableView.beginUpdates()
            places.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .automatic)
            tableView.endUpdates()
            
        }
        
    }
    
}


extension ViewController: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        guard let location = locations.first, location.horizontalAccuracy <= 10.0 else { return }
        
        current_location = location
        
        locationManager.stopUpdatingLocation()
        
        optimizeRoute()
        
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        
        if status == .authorizedAlways {}
        
    }
    
}
