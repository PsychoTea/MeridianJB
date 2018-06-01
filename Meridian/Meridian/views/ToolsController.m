//
//  ToolsController.m
//  Meridian
//
//  Created by Sticktron on 2018-04-03.
//  Copyright © 2018 Ben Sparkes. All rights reserved.
//

#import "ToolsController.h"

@interface ToolsController ()
@property (weak, nonatomic) IBOutlet UITableViewCell *reinstallBootstrapCell;
@property (weak, nonatomic) IBOutlet UITableViewCell *reinstallCydiaCell;
@property (weak, nonatomic) IBOutlet UITableViewCell *deleteCydiaCell;
@property (weak, nonatomic) IBOutlet UITableViewCell *extractDPKGCell;
@end


@implementation ToolsController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:@"Close"
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction * action) {}];
    [alert addAction:defaultAction];
    
    [self presentViewController:alert animated:YES completion:nil];
}


#pragma mark - Table view

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (cell == self.reinstallBootstrapCell) {
        [self showAlertWithTitle:@"Reinstall Bootstrap?" message:@"WARNING: Lorem ipsum dolor sit amet."];

    } else if (cell == self.reinstallCydiaCell) {
        [self showAlertWithTitle:@"Reinstall Cydia?" message:@"WARNING: Lorem ipsum dolor sit amet."];

    } else if (cell == self.deleteCydiaCell) {
        [self showAlertWithTitle:@"Delete Cydia?" message:@"WARNING: Lorem ipsum dolor sit amet."];

    } else if (cell == self.extractDPKGCell) {
        [self showAlertWithTitle:@"Extract DPKG?" message:@"WARNING: Lorem ipsum dolor sit amet."];
    }
}


#pragma mark - Navigation

/*
// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
