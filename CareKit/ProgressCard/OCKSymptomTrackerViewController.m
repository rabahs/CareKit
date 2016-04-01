/*
 Copyright (c) 2016, Apple Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:
 
 1.  Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.
 
 2.  Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation and/or
 other materials provided with the distribution.
 
 3.  Neither the name of the copyright holder(s) nor the names of any contributors
 may be used to endorse or promote products derived from this software without
 specific prior written permission. No license is granted to the trademarks of
 the copyright holders even if such marks are included in this software.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
 FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import "OCKSymptomTrackerViewController.h"
#import "OCKWeekViewController.h"
#import "OCKSymptomTrackerWeekView.h"
#import "NSDateComponents+CarePlanInternal.h"
#import "OCKSymptomTrackerTableViewHeader.h"
#import "OCKSymptomTrackerTableViewCell.h"
#import "OCKHeartView.h"
#import "OCKWeekLabelsView.h"
#import "OCKCarePlanStore_Internal.h"
#import "OCKHelpers.h"
#import "OCKDefines_Private.h"


static const CGFloat HeaderViewHeight = 150.0;

@interface OCKSymptomTrackerViewController() <OCKWeekViewDelegate, OCKCarePlanStoreDelegate, UITableViewDelegate, UITableViewDataSource, UIPageViewControllerDelegate, UIPageViewControllerDataSource>

@property (nonatomic) NSDateComponents *selectedDate;

@end


@implementation OCKSymptomTrackerViewController {
    UITableView *_tableView;
    NSMutableArray<NSMutableArray<OCKCarePlanEvent *> *> *_events;
    NSMutableArray *_weekValues;
    OCKSymptomTrackerTableViewHeader *_headerView;
    UIPageViewController *_pageViewController;
    OCKWeekViewController *_weekViewController;
    NSCalendar *_calendar;
    NSMutableArray *_constraints;
}

- (instancetype)init {
    OCKThrowMethodUnavailableException();
    return nil;
}

- (instancetype)initWithCarePlanStore:(OCKCarePlanStore *)store {
    self = [super init];
    if (self) {
        _store = store;
        _store.symptomTrackerUIDelegate = self;
        
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:OCKLocalizedString(@"TODAY_BUTTON_TITLE", nil)
                                                                                  style:UIBarButtonItemStylePlain
                                                                                 target:self
                                                                                 action:@selector(showToday:)];
        
        _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
        _tableView.dataSource = self;
        _tableView.delegate = self;
        [self.view addSubview:_tableView];
        
        [self prepareView];
        
        _calendar = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
        
        self.selectedDate = [NSDateComponents ock_componentsWithDate:[NSDate date] calendar:_calendar];
        
        _tableView.estimatedRowHeight = 90.0;
        _tableView.rowHeight = UITableViewAutomaticDimension;
    }
    return self;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    NSAssert(self.navigationController, @"OCKProgressCardViewController must be embedded in a navigation controller.");
    _weekViewController.symptomTrackerWeekView.delegate = self;
}

- (void)showToday:(id)sender {
    self.selectedDate = [NSDateComponents ock_componentsWithDate:[NSDate date] calendar:_calendar];
}

- (void)prepareView {
    if (!_headerView) {
        _headerView = [[OCKSymptomTrackerTableViewHeader alloc] initWithFrame:CGRectMake(0, 0, _tableView.frame.size.width, HeaderViewHeight)];
    }
    [self updateHeaderView];
    
    if (!_pageViewController) {
        _pageViewController = [[UIPageViewController alloc] initWithTransitionStyle:UIPageViewControllerTransitionStyleScroll
                                                              navigationOrientation:UIPageViewControllerNavigationOrientationHorizontal
                                                                            options:nil];
        _pageViewController.dataSource = self;
        _pageViewController.delegate = self;
        
        OCKWeekViewController *weekController = [[OCKWeekViewController alloc] initWithShowCareCardWeekView:NO];
        weekController.symptomTrackerWeekView.delegate = _weekViewController.symptomTrackerWeekView.delegate;
        _weekViewController = weekController;
        
        [_pageViewController setViewControllers:@[weekController] direction:UIPageViewControllerNavigationDirectionForward animated:YES completion:nil];
    }
    
    _tableView.tableHeaderView = _pageViewController.view;
    _tableView.tableFooterView = [UIView new];
    
    [self setUpConstraints];
}

- (void)setUpConstraints {
    [NSLayoutConstraint deactivateConstraints:_constraints];
    
    _constraints = [NSMutableArray new];
    
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _pageViewController.view.translatesAutoresizingMaskIntoConstraints = NO;
    
    [_constraints addObjectsFromArray:@[
                                        [NSLayoutConstraint constraintWithItem:_tableView
                                                                     attribute:NSLayoutAttributeTop
                                                                     relatedBy:NSLayoutRelationEqual
                                                                        toItem:self.view
                                                                     attribute:NSLayoutAttributeTop
                                                                    multiplier:1.0
                                                                      constant:0.0],
                                        [NSLayoutConstraint constraintWithItem:_tableView
                                                                     attribute:NSLayoutAttributeBottom
                                                                     relatedBy:NSLayoutRelationEqual
                                                                        toItem:self.view
                                                                     attribute:NSLayoutAttributeBottom
                                                                    multiplier:1.0
                                                                      constant:0.0],
                                        [NSLayoutConstraint constraintWithItem:_tableView
                                                                     attribute:NSLayoutAttributeLeading
                                                                     relatedBy:NSLayoutRelationEqual
                                                                        toItem:self.view
                                                                     attribute:NSLayoutAttributeLeading
                                                                    multiplier:1.0
                                                                      constant:0.0],
                                        [NSLayoutConstraint constraintWithItem:_tableView
                                                                     attribute:NSLayoutAttributeTrailing
                                                                     relatedBy:NSLayoutRelationEqual
                                                                        toItem:self.view
                                                                     attribute:NSLayoutAttributeTrailing
                                                                    multiplier:1.0
                                                                      constant:0.0],
                                        [NSLayoutConstraint constraintWithItem:_pageViewController.view
                                                                     attribute:NSLayoutAttributeWidth
                                                                     relatedBy:NSLayoutRelationEqual
                                                                        toItem:nil
                                                                     attribute:NSLayoutAttributeNotAnAttribute
                                                                    multiplier:1.0
                                                                      constant:self.view.frame.size.width],
                                        [NSLayoutConstraint constraintWithItem:_pageViewController.view
                                                                     attribute:NSLayoutAttributeHeight
                                                                     relatedBy:NSLayoutRelationEqual
                                                                        toItem:nil
                                                                     attribute:NSLayoutAttributeNotAnAttribute
                                                                    multiplier:1.0
                                                                      constant:60.0],
                                        [NSLayoutConstraint constraintWithItem:_pageViewController.view
                                                                     attribute:NSLayoutAttributeCenterX
                                                                     relatedBy:NSLayoutRelationEqual
                                                                        toItem:self.view
                                                                     attribute:NSLayoutAttributeCenterX
                                                                    multiplier:1.0
                                                                      constant:0.0]
                                        ]];
    
    [NSLayoutConstraint activateConstraints:_constraints];
}

- (void)setSelectedDate:(NSDateComponents *)selectedDate {
    NSDateComponents *today = [self today];
    _selectedDate = [selectedDate isLaterThan:today] ? today : selectedDate;
    
    _weekViewController.symptomTrackerWeekView.selectedIndex = self.selectedDate.weekday - 1;
    
    [self fetchEvents];
}


#pragma mark - Helpers

- (void)fetchEvents {
    [_store eventsOnDate:_selectedDate
                    type:OCKCarePlanActivityTypeAssessment
              completion:^(NSArray<NSArray<OCKCarePlanEvent *> *> * _Nonnull eventsGroupedByActivity, NSError * _Nonnull error) {
                  NSAssert(!error, error.localizedDescription);
                  dispatch_async(dispatch_get_main_queue(), ^{
                      _events = [NSMutableArray new];
                      for (NSArray<OCKCarePlanEvent *> *events in eventsGroupedByActivity) {
                          [_events addObject:[events mutableCopy]];
                      }
                      
                      if (_delegate &&
                          [_delegate respondsToSelector:@selector(symptomTrackerViewController:willDisplayEvents:ofDate:)]) {
                          [_delegate symptomTrackerViewController:self willDisplayEvents:[_events copy] ofDate:_selectedDate];
                      }
                      
                      [self updateHeaderView];
                      [self updateWeekView];
                      [_tableView reloadData];
                  });
              }];
}

- (void)updateHeaderView {
    _headerView.date = [NSDateFormatter localizedStringFromDate:_selectedDate.dateWithGregorianCalendar
                                                      dateStyle:NSDateFormatterLongStyle
                                                      timeStyle:NSDateFormatterNoStyle];
    
    NSInteger totalEvents = 0;
    NSInteger completedEvents = 0;
    for (NSArray<OCKCarePlanEvent *> *events in _events) {
        totalEvents += events.count;
        OCKCarePlanEvent *evaluationEvent = events.firstObject;
        if (evaluationEvent.state == OCKCarePlanEventStateCompleted) {
            completedEvents++;
        }
    }
    
    float progress = (totalEvents > 0) ? (float)completedEvents/totalEvents : 1;
    _headerView.value = progress;
    
    NSInteger selectedIndex = _weekViewController.symptomTrackerWeekView.selectedIndex;
    [_weekValues replaceObjectAtIndex:selectedIndex withObject:@(progress)];
    _weekViewController.symptomTrackerWeekView.values = _weekValues;
}

- (void)updateWeekView {
    NSDate *selectedDate = _selectedDate.dateWithGregorianCalendar;
    NSDate *startOfWeek;
    NSTimeInterval interval;
    [_calendar rangeOfUnit:NSCalendarUnitWeekOfMonth
                 startDate:&startOfWeek
                  interval:&interval
                   forDate:selectedDate];
    NSDate *endOfWeek = [startOfWeek dateByAddingTimeInterval:interval-1];
    
    NSMutableArray *values = [NSMutableArray new];
    
    [_store dailyCompletionStatusWithType:OCKCarePlanActivityTypeAssessment
                                startDate:[NSDateComponents ock_componentsWithDate:startOfWeek calendar:_calendar]
                                  endDate:[NSDateComponents ock_componentsWithDate:endOfWeek calendar:_calendar]
                                  handler:^(NSDateComponents * _Nonnull date, NSUInteger completedEvents, NSUInteger totalEvents) {
                                      if ([date isLaterThan:[self today]]) {
                                          [values addObject:@(0)];
                                      } else if (totalEvents == 0) {
                                          [values addObject:@(1)];
                                      } else {
                                          [values addObject:@((float)completedEvents/totalEvents)];
                                      }
                                  } completion:^(BOOL completed, NSError * _Nullable error) {
                                      NSAssert(!error, error.localizedDescription);
                                      dispatch_async(dispatch_get_main_queue(), ^{
                                          _weekViewController.symptomTrackerWeekView.values = values;
                                          _weekValues = [values mutableCopy];
                                      });
                                  }];
    
}

- (NSDateComponents *)dateFromSelectedIndex:(NSInteger)index {
    NSDateComponents *newComponents = [NSDateComponents new];
    newComponents.year = _selectedDate.year;
    newComponents.month = _selectedDate.month;
    newComponents.weekOfMonth = _selectedDate.weekOfMonth;
    newComponents.weekday = index + 1;
    
    NSDate *newDate = [_calendar dateFromComponents:newComponents];
    return [NSDateComponents ock_componentsWithDate:newDate calendar:_calendar];
}

- (NSDateComponents *)today {
    return [NSDateComponents ock_componentsWithDate:[NSDate date] calendar:_calendar];
}


#pragma mark - OCKWeekViewDelegate

- (void)weekViewSelectionDidChange:(UIView *)weekView {
    OCKSymptomTrackerWeekView *progressCardWeekView = (OCKSymptomTrackerWeekView *)weekView;
    NSDateComponents *selectedDate = [self dateFromSelectedIndex:progressCardWeekView.selectedIndex];
    self.selectedDate = selectedDate;
}


#pragma mark - OCKCarePlanStoreDelegate

- (void)carePlanStore:(OCKCarePlanStore *)store didReceiveUpdateOfEvent:(OCKCarePlanEvent *)event {
    for (NSMutableArray<OCKCarePlanEvent *> *events in _events) {
        if ([events.firstObject.activity.identifier isEqualToString:event.activity.identifier]) {
            
            if (events[event.occurrenceIndexOfDay].numberOfDaysSinceStart == event.numberOfDaysSinceStart) {
                [events replaceObjectAtIndex:event.occurrenceIndexOfDay withObject:event];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self updateHeaderView];
                    
                    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:[_events indexOfObject:events] inSection:0];
                    [_tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
                });
            }
            break;
        }
    }}

- (void)carePlanStoreEvaluationListDidChange:(OCKCarePlanStore *)store {
    [self fetchEvents];
}


#pragma mark - UIPageViewControllerDelegate

- (void)pageViewController:(UIPageViewController *)pageViewController didFinishAnimating:(BOOL)finished previousViewControllers:(NSArray<UIViewController *> *)previousViewControllers transitionCompleted:(BOOL)completed {
    if (completed) {
        OCKWeekViewController *controller = (OCKWeekViewController *)pageViewController.viewControllers.firstObject;
        controller.symptomTrackerWeekView.delegate = _weekViewController.symptomTrackerWeekView.delegate;
        
        NSDateComponents *components = [NSDateComponents new];
        components.day = (controller.weekIndex > _weekViewController.weekIndex) ? 7 : -7;
        NSDate *newDate = [_calendar dateByAddingComponents:components toDate:self.selectedDate.dateWithGregorianCalendar options:0];
        
        _weekViewController = controller;
        self.selectedDate = [NSDateComponents ock_componentsWithDate:newDate calendar:_calendar];
    }
}


#pragma mark - UIPageViewControllerDataSource

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerBeforeViewController:(UIViewController *)viewController {
    OCKWeekViewController *controller = [[OCKWeekViewController alloc] initWithShowCareCardWeekView:NO];
    controller.weekIndex = ((OCKWeekViewController *)viewController).weekIndex - 1;
    return controller;
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerAfterViewController:(UIViewController *)viewController {
    OCKWeekViewController *controller = [[OCKWeekViewController alloc] initWithShowCareCardWeekView:NO];
    controller.weekIndex = ((OCKWeekViewController *)viewController).weekIndex + 1;
    return (![self.selectedDate isInSameWeekAsDate:[self today]]) ? controller : nil;
}


#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return HeaderViewHeight;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    return _headerView;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    OCKCarePlanEvent *selectedEvent = _events[indexPath.row].firstObject;
    _lastSelectedAssessmentEvent = selectedEvent;
    
    if (_delegate &&
        [_delegate respondsToSelector:@selector(symptomTrackerViewController:didSelectRowWithAssessmentEvent:)]) {
        [_delegate symptomTrackerViewController:(OCKSymptomTrackerViewController *)self.parentViewController didSelectRowWithAssessmentEvent:selectedEvent];
    }
    
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
}


#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _events.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"ProgressCardCell";
    OCKSymptomTrackerTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (!cell) {
        cell = [[OCKSymptomTrackerTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                     reuseIdentifier:CellIdentifier];
    }
    cell.assessmentEvent = _events[indexPath.row].firstObject;
    return cell;
}


@end
