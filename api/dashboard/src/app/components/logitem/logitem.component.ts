import { Component, Input, OnInit } from '@angular/core';

@Component({
  selector: 'app-logitem',
  templateUrl: './logitem.component.html',
  styleUrls: ['./logitem.component.css']
})
export class LogitemComponent implements OnInit {
  @Input() item: string | undefined;
  
  constructor() { }

  ngOnInit(): void {
  }

}
