//
//  ViewController.m
//  Meridian
//
//  Created by Ben Sparkes on 22/12/2017.
//  Copyright © 2017 Ben Sparkes. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UIButton *goButton;
@property (weak, nonatomic) IBOutlet UIButton *creditsButton;
@property (weak, nonatomic) IBOutlet UIButton *sourceButton;
@property (weak, nonatomic) IBOutlet UITextView *textArea;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _goButton.layer.cornerRadius = 5;
    _creditsButton.layer.cornerRadius = 5;
    _sourceButton.layer.cornerRadius = 5;

    [self writeText:@"> ready."];
}

- (IBAction)goButtonPressed:(UIButton *)sender {
    [self writeText:@"go pressed"];
}

- (void)writeText:(NSString *)message {
    _textArea.text = [_textArea.text stringByAppendingString:[NSString stringWithFormat:@"%@\n", message]];
    
    NSRange bottom = NSMakeRange(_textArea.text.length - 1, 1);
    [self.textArea scrollRangeToVisible:bottom];
}

@end
