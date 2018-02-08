//
//  CreditsController.m
//  Meridian
//
//  Created by Ben Sparkes on 22/12/2017.
//  Copyright © 2017 Ben Sparkes. All rights reserved.
//

#import "CreditsController.h"

@interface CreditsController ()
@property (weak, nonatomic) IBOutlet UITextView *creditsText;
@end

@implementation CreditsController

- (void)viewDidLayoutSubviews {
    [self.creditsText setContentOffset:CGPointZero animated:NO];
}

- (IBAction)closeButton:(id)sender {
    [self dismissViewControllerAnimated:TRUE completion:nil];
}
    
@end
