import { Component, OnInit } from '@angular/core';
import { map, share } from 'rxjs/operators';
import { from, Observable } from "rxjs";
import {io} from 'socket.io-client';

@Component({
  selector: 'app-console',
  templateUrl: './console.component.html',
  styleUrls: ['./console.component.css'],
})
export class ConsoleComponent implements OnInit {
  constructor() {}

  socket: any;
  processData: string[] = [];
  command: any;

  ngOnInit(): void {

    this.socket = io('http://localhost:5000');

    this.fromEvent('process_data').subscribe(data => {
      this.processData.push(data);
    });

    this.command = this.fromEvent('command');

  }

  fromEvent(event: string): Observable<string> {
    return new Observable<string>((subscriber) => { 
      this.socket.on(event, (data: string) => {
        subscriber.next(data);
      });
    })
  }
}
