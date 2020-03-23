//
//  ViewController.swift
//  SwiflyCacheDemo
//
//  Created by 黄琳川 on 2020/3/20.
//  Copyright © 2020 黄琳川. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let newButton:UIButton = UIButton(frame: CGRect(x: 100, y: 100, width: 100, height: 100))
        newButton.backgroundColor = UIColor.blue
        newButton.setTitle("点我", for: .normal)
        self.view.addSubview(newButton)
        newButton.addTarget(self, action: #selector(buttonClick(button:)), for: .touchUpInside)
//        memorySetObjectTest()
//        memoryGetObjectTest()
//        memoryIsExistsObjectForKeyTest()
}
    
        @objc func buttonClick(button:UIButton ){
            let vc = MainViewController()
            self.navigationController?.pushViewController(vc, animated: true)
        }
}

