//
//  ARMotionViewController+extension.swift
//  DamdaCam
//
//  Created by Yebin Kim on 2020/02/16.
//  Copyright © 2020 김예빈. All rights reserved.
//

import UIKit

extension ARMotionViewController: UIPickerViewDelegate, UIPickerViewDataSource {
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 2
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        if component == 0 {
            return 60
        } else {
            return 10
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
        let title = UILabel()
        title.font = Properties.shared.font.regular(15.0)
        title.textColor = Properties.shared.color.darkGray
        title.text = String(row)
        title.textAlignment = .center
        
        if component == 0 {
            return title
        } else {
            return title
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        clipTime = (Double(plusClipPicker.selectedRow(inComponent: 0)) * 60.0) + Double(plusClipPicker.selectedRow(inComponent: 1))
    }
    
}

extension ARMotionViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView == self.arMotionCollectionView {
            if myARMotionButton.isSelected {
                return myARMotionArray.count
            } else if allARMotionButton.isSelected {
                return allARMotionArray.count
            } else if faceARMotionButton.isSelected {
                return faceARMotionArray.count
            } else if bgARMotionButton.isSelected {
                return bgARMotionArray.count
            }
        }
        
        if collectionView == self.filterCollectionView {
            return 0
        }
        
        return 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView == self.arMotionCollectionView {
            guard let arMotionCell = collectionView.dequeueReusableCell(withReuseIdentifier: "ARMotionCell", for: indexPath) as? ARMotionCollectionViewCell else { return UICollectionViewCell() }
            
            //            arMotionCell.stateChangeButton.isHidden = true
            //            arMotionCell.stateChangeButton.alpha = 0.0
            
            arMotionCell.layer.shadowOpacity = 0.6
            arMotionCell.layer.shadowRadius = 1
            arMotionCell.layer.shadowColor = Properties.shared.color.darkGray.cgColor
            arMotionCell.layer.shadowOffset = CGSize(width: 1, height: 1)
            
            if myARMotionButton.isSelected {
                arMotionCell.previewImage.image = myARMotionArray[indexPath.row]
                
                return arMotionCell
            } else if allARMotionButton.isSelected {
                arMotionCell.previewImage.image = allARMotionArray[indexPath.row]
                
                return arMotionCell
            } else if faceARMotionButton.isSelected {
                arMotionCell.previewImage.image = faceARMotionArray[indexPath.row]
                
                return arMotionCell
            } else {    // if BGarMotionButton.isSelected
                arMotionCell.previewImage.image = bgARMotionArray[indexPath.row]
                
                return arMotionCell
            }
        } else {
            guard let filterCell = collectionView.dequeueReusableCell(withReuseIdentifier: "FilterCell", for: indexPath) as? FilterCollectionViewCell else { return UICollectionViewCell() }
            
            filterCell.filterPreviewImage.image = UIImage(named: "filter_image")
            if indexPath.row > 0 {
                filterCell.filterNameLabel.text = "damda\(indexPath.row)"
            }
            
            return filterCell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if collectionView == self.arMotionCollectionView {
            guard collectionView.dequeueReusableCell(withReuseIdentifier: "ARMotionCell", for: indexPath) is ARMotionCollectionViewCell else { return }
            
            let bgARMotionIndex = faceARMotionArray.count
            
            self.arMotionDelete()
            
            if myARMotionButton.isSelected {
                
            } else if allARMotionButton.isSelected {
                if indexPath.row == 0 {
                    self.loadarMotionNode("heart", position: SCNVector3(x: 0, y: 3.5, z: -5))
                } else if indexPath.row == 1 {
                    self.loadarMotionNode("angel", position: SCNVector3(x: 0, y: 0, z: -5))
                } else if indexPath.row == 2 {
                    self.loadarMotionNode("rabbit", position: SCNVector3(x: 0, y: 3.5, z: -5), isHead: true)
                } else if indexPath.row == 3 {
                    self.loadarMotionNode("cat", position: SCNVector3(x: 0, y: 3.5, z: -5), isHead: true)
                } else if indexPath.row == 4 {
                    self.loadarMotionNode("mouse", position: SCNVector3(x: 0, y: 3.5, z: -5), isHead: true)
                } else if indexPath.row == 5 {
                    self.loadarMotionNode("peach", position: SCNVector3(x: 0, y: 4.35, z: -5))
                } else if indexPath.row == 6 {
                    self.loadarMotionNode("baaan", position: SCNVector3(x: 0, y: 4, z: -5))
                } else if indexPath.row == 7 {
                    if isBlink {
                        self.loadarMotionNode("mushroom1", position: SCNVector3(x: 0, y: 2.5, z: -5), isHead: true)
                    } else {
                        self.loadarMotionNode("mushroom2", position: SCNVector3(x: 0, y: 2.5, z: -5), isHead: true)
                    }
                    isBlink = !isBlink
                } else if indexPath.row == 8 {
                    self.loadarMotionNode("soughnut1", position: SCNVector3(x: 0, y: -4, z: -5))
                } else if indexPath.row == 9 {
                    self.loadarMotionNode("flower3", position: SCNVector3(x: 0, y: 0, z: -5))
                } else if indexPath.row == bgARMotionIndex {
                    self.loadBGMotionNode("snow")
                } else if indexPath.row == bgARMotionIndex + 1 {
                    self.loadBGMotionNode("blossom")
                } else if indexPath.row == bgARMotionIndex + 2 {
                    self.loadBGMotionNode("rain")
                } else if indexPath.row == bgARMotionIndex + 3 {
                    self.loadBGMotionNode("fish")
                } else if indexPath.row == bgARMotionIndex + 4 {
                    self.loadBGMotionNode("greenery")
                } else if indexPath.row == bgARMotionIndex + 5 {
                    self.loadBGMotionNode("fruits")
                } else if indexPath.row == bgARMotionIndex + 6 {
                    self.loadBGMotionNode("glow")
                } else {
                    self.arMotionSelected_MakingAR(index: indexPath.row)
                }
            } else if faceARMotionButton.isSelected {
                if indexPath.row == 0 {
                    self.loadarMotionNode("heart", position: SCNVector3(x: 0, y: 3.5, z: -5))
                } else if indexPath.row == 1 {
                    self.loadarMotionNode("angel", position: SCNVector3(x: 0, y: 0, z: -5))
                } else if indexPath.row == 2 {
                    self.loadarMotionNode("rabbit", position: SCNVector3(x: 0, y: 3.5, z: -5))
                } else if indexPath.row == 3 {
                    self.loadarMotionNode("cat", position: SCNVector3(x: 0, y: 3.5, z: -5), isHead: true)
                } else if indexPath.row == 4 {
                    self.loadarMotionNode("mouse", position: SCNVector3(x: 0, y: 3.5, z: -5), isHead: true)
                } else if indexPath.row == 5 {
                    self.loadarMotionNode("peach", position: SCNVector3(x: 0, y: 4.35, z: -5))
                } else if indexPath.row == 6 {
                    self.loadarMotionNode("baaam", position: SCNVector3(x: 0, y: 4, z: -5))
                } else if indexPath.row == 7 {
                    if isBlink {
                        self.loadarMotionNode("mushroom1", position: SCNVector3(x: 0, y: 2.5, z: -5), isHead: true)
                    } else {
                        self.loadarMotionNode("mushroom2", position: SCNVector3(x: 0, y: 2.5, z: -5), isHead: true)
                    }
                    isBlink = !isBlink
                } else if indexPath.row == 8 {
                    self.loadarMotionNode("doughnut1", position: SCNVector3(x: 0, y: -4, z: -5))
                } else if indexPath.row == 9 {
                    self.loadarMotionNode("flower3", position: SCNVector3(x: 0, y: 0, z: -5))
                } else {
                    self.arMotionSelected_MakingAR(index: indexPath.row)
                }
            } else {    // if BGarMotionButton.isSelected
                if indexPath.row == 0 {
                    self.loadBGMotionNode("snow")
                } else if indexPath.row == 1 {
                    self.loadBGMotionNode("blossom")
                } else if indexPath.row == 2 {
                    self.loadBGMotionNode("rain")
                } else if indexPath.row == 3 {
                    self.loadBGMotionNode("fish")
                } else if indexPath.row == 4 {
                    self.loadBGMotionNode("greenery")
                } else if indexPath.row == 5 {
                    self.loadBGMotionNode("fruits")
                } else if indexPath.row == 6 {
                    self.loadBGMotionNode("glow")
                }
            }
        }
    }
    
    @objc func arMotionCellLongPress(gesture: UILongPressGestureRecognizer!) {
        if gesture.state != .ended {
            return
        }
        
        let p = gesture.location(in: self.arMotionCollectionView)
        
        if let indexPath = self.arMotionCollectionView.indexPathForItem(at: p) {
            guard let arMotionCell = arMotionCollectionView.dequeueReusableCell(withReuseIdentifier: "ARMotionCell", for: indexPath) as? ARMotionCollectionViewCell else { return }
            
            if allARMotionButton.isSelected || faceARMotionButton.isSelected {
                if indexPath.row > 9 {
                    //                    arMotionCell.stateChangeButton.setImage(UIImage(named: "ic_mini_x"), for: .normal)
                    //                    arMotionCell.stateChangeButton.isHidden = false
                    
                    //                    UIView.animate(withDuration: Double(0.5), animations: {
                    //                        arMotionCell.stateChangeButton.alpha = 1.0
                    //                    })
                }
            }
            print(indexPath)
        } else {
            print("couldn't find index path")
        }
    }
    
    @objc func arMotionCellDoubleTab(gesture: UITapGestureRecognizer!) {
        let p = gesture.location(in: self.arMotionCollectionView)
        
        if let indexPath = self.arMotionCollectionView.indexPathForItem(at: p) {
            // get the cell at indexPath (the one you long pressed)
            let cell = self.arMotionCollectionView.cellForItem(at: indexPath)
            // do stuff with the cell
            print(indexPath)
        } else {
            print("couldn't find index path")
        }
    }
    
}
