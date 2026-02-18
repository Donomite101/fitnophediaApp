class ClassImageHelper {
  static String getCategoryImage(String category) {
    switch (category.toLowerCase()) {
      case 'yoga':
        return 'https://res.cloudinary.com/dntnzraxh/image/upload/v1770998318/y0xhnchj21cbdh8zsl0t.jpg';
      case 'hiit':
        return 'https://res.cloudinary.com/dntnzraxh/image/upload/v1770998321/bmpylioxihpazitapjji.jpg';
      case 'strength':
      case 'weightlifting':
        return 'https://res.cloudinary.com/dntnzraxh/image/upload/v1770998324/j4aotiq9vmnrfufh3u3i.jpg';
      case 'cardio':
        return 'https://res.cloudinary.com/dntnzraxh/image/upload/v1770998327/tftpra06w2x4olqhuwoj.jpg';
      case 'pilates':
        return 'https://res.cloudinary.com/dntnzraxh/image/upload/v1770998330/zfuwgbj0ydwjk0gxvg67.jpg';
      case 'zumba':
      case 'dance':
        return 'https://images.unsplash.com/photo-1524594152303-9fd13543fe6e?q=80&w=800&auto=format&fit=crop';
      case 'boxing':
      case 'martial_arts':
      case 'kickboxing':
        return 'https://images.unsplash.com/photo-1549719386-74dfcbf7dbed?q=80&w=800&auto=format&fit=crop';
      case 'swimming':
        return 'https://images.unsplash.com/photo-1530549387789-4c1017266635?q=80&w=800&auto=format&fit=crop';
      case 'cycling':
      case 'spin':
        return 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?q=80&w=800&auto=format&fit=crop';
      case 'crossfit':
        return 'https://images.unsplash.com/photo-1517963879466-e9b5ce382569?q=80&w=800&auto=format&fit=crop';
      case 'senior': 
        return 'https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?q=80&w=800&auto=format&fit=crop';
      default:
        return 'https://images.unsplash.com/photo-1571902943202-507ec2618e8f?q=80&w=800&auto=format&fit=crop';
    }
  }

  static bool isAsset(String path) {
    return path.startsWith('assets/');
  }
}
