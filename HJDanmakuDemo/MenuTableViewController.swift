//
//  MenuTableViewController.swift
//  HJDanmaku-Swift
//
//  Created by haijiao on 2017/7/31.
//  Copyright © 2017年 olinone. All rights reserved.
//

import UIKit

class MenuTableViewController: UITableViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "olinone"
        self.tableView.rowHeight = 64.0
        self.tableView.register(UITableViewCell.classForCoder(), forCellReuseIdentifier: "cell")
    }
    
    // MARK: -
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        var vc: UIViewController? = nil
        
        switch indexPath.row {
            case 0:
                vc = VideoDemoViewController.init();
            case 1:
                vc = LiveDemoViewController.init();
            default:
                break
        }
        
        self.navigationController?.pushViewController(vc!, animated: true)
    }

    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        
        switch indexPath.row {
            case 0:
                cell.textLabel?.text = "VideoMode"
            case 1:
                cell.textLabel?.text = "LiveMode"
            default:
                break
        }
        
        return cell
    }

}
