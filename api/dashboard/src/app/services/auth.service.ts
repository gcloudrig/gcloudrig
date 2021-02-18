import { HttpClient, HttpErrorResponse } from '@angular/common/http';
import { Injectable } from '@angular/core';
import { tap } from 'rxjs/operators';

export interface Bearer {
  accessToken: string;
}

@Injectable({
  providedIn: 'root',
})

export class AuthService {
  constructor(private http: HttpClient) {}

  login(username: string, password: string) {
    return this.http
      .post<Bearer>('http://localhost:5000/v1/auth/login', { username: username, password: password })
      .pipe(
        tap(data => this.setSession(data.accessToken))
      );
  }

  private setSession(authResult: string) {
    localStorage.setItem('auth_token', authResult);
  }

  logout() {
    localStorage.removeItem('auth_token');
  }

  public isLoggedIn() {
    if (
      localStorage.getItem('auth_token') != null &&
      localStorage.getItem('auth_token') != ''
    ) {
      return true;
    } else {
      return false;
    }
  }

  isLoggedOut() {
    return !this.isLoggedIn();
  }
}
