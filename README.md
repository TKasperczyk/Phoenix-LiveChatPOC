# 💬 Phoenix LiveView Chat POC

![Elixir](https://img.shields.io/badge/Elixir-4B275F?style=for-the-badge&logo=elixir&logoColor=white)
![Phoenix Framework](https://img.shields.io/badge/Phoenix_Framework-FD4F00?style=for-the-badge&logo=phoenix-framework&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-316192?style=for-the-badge&logo=postgresql&logoColor=white)

## 🌟 Overview

This project is a Proof of Concept (POC) chat application developed as part of my journey in learning Elixir and Phoenix LiveView. It showcases the power of Phoenix LiveView for building real-time, interactive web applications with minimal JavaScript.

## ✨ Features

- **Real-time Chat**: Instant messaging functionality with live updates.
- **Direct Messaging**: Support for one-on-one conversations.
- **User Presence**: Real-time tracking of online users.
- **User Authentication**: Secure login and registration system.
- **Avatar Management**: Users can upload and update their profile pictures.
- **Emoji Picker**: Rich emoji support for expressive messaging.
- **Message History**: Persistent chat history with pagination.
- **Global Tag Invalidation**: Automatic data refetching mechanism similar to RTK-Query.

## 🛠️ Tech Stack

- **Elixir**: The primary programming language.
- **Phoenix Framework**: Web framework for Elixir.
- **Phoenix LiveView**: For building real-time features with server-rendered HTML.
- **PostgreSQL**: Database for persistent storage.
- **TailwindCSS**: For responsive and modern UI design.

## 🚀 Key Implementations

### Global Tag Invalidation and Auto-Refetching
- Implemented a mechanism similar to RTK-Query for automatic data invalidation and refetching.
- Uses Phoenix PubSub for broadcasting invalidation events.
- Allows for efficient, real-time updates across the application without manual refresh.

### Real-time Presence
- Utilizes Phoenix Presence to track and display online users in real-time.
- Provides instant feedback on user availability.

### Optimized Message Rendering
- Implements efficient message grouping and time-based separators.
- Enhances readability and performance for chat history display.

### File Upload and Image Processing
- Integrated avatar upload functionality with server-side image processing.
- Uses Mogrify for image manipulation (resizing, format conversion).

### Security Measures
- Implements secure user authentication and authorization.
- Uses Phoenix's built-in CSRF protection and secure session management.

## 🚧 Current Status

This project is in active development. It serves as a learning platform for exploring Elixir and Phoenix best practices. Expect frequent updates and potential refactoring as new techniques are discovered and implemented.

## 🚀 Getting Started

```bash
# Clone the repository
git clone https://github.com/TKasperczyk/Phoenix-LiveChatPOC.git

# Navigate to the project directory
cd Phoenix-LiveChatPOC

# Install dependencies
mix deps.get

# Create and migrate the database
mix ecto.setup

# Start the Phoenix server
mix phx.server