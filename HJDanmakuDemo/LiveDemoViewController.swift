//
//  LiveDemoViewController.swift
//  HJDanmaku-Swift
//
//  Created by haijiao on 2017/8/2.
//  Copyright © 2017年 olinone. All rights reserved.
//

import UIKit
import HJDanmaku_Swift

class LiveDemoViewController: UIViewController {
    
    @IBAction func onBackClick(button: UIButton) -> Void {
        button.isHidden = true
        self.navigationController?.setNavigationBarHidden(false, animated: true)
        self.navigationController?.popViewController(animated: true)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = UIColor.white
        self.navigationController?.setNavigationBarHidden(true, animated: true)

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
