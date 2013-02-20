//
//  ViewController.h
//  ruanji
//
//  Created by 赵君 on 13-2-19.
//  Copyright (c) 2013年 赵君. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>

@interface ViewController : UIViewController <AVAudioRecorderDelegate, AVAudioPlayerDelegate>
@property (weak, nonatomic) IBOutlet UILabel *frequency;
- (IBAction)start:(id)sender;

@end
