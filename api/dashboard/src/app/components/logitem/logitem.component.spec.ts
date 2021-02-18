import { ComponentFixture, TestBed } from '@angular/core/testing';

import { LogitemComponent } from './logitem.component';

describe('LogitemComponent', () => {
  let component: LogitemComponent;
  let fixture: ComponentFixture<LogitemComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      declarations: [ LogitemComponent ]
    })
    .compileComponents();
  });

  beforeEach(() => {
    fixture = TestBed.createComponent(LogitemComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
