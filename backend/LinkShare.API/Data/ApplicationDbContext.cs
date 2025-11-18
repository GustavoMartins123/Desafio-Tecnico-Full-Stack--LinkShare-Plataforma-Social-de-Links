using LinkShare.API.Entities;
using Microsoft.EntityFrameworkCore;

namespace LinkShare.API.Data;

public class ApplicationDbContext : DbContext
{
    public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options)
        : base(options)
    {
    }

    public DbSet<User> Users { get; set; } = null!;
    public DbSet<Profile> Profiles { get; set; } = null!;
    public DbSet<Friendship> Friendships { get; set; } = null!;
    public DbSet<Collection> Collections { get; set; } = null!;
    public DbSet<LinkItem> LinkItems { get; set; } = null!;
    public DbSet<CollectionShare> CollectionShares { get; set; } = null!;
    public DbSet<UserToken> UserTokens { get; set; } = null!;
    public DbSet<UserDevice> UserDevices { get; set; } = null!;

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        // User Configuration
        modelBuilder.Entity<User>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.HasIndex(e => e.Email).IsUnique();
            entity.HasIndex(e => e.Username).IsUnique();
            entity.Property(e => e.Email).IsRequired().HasMaxLength(255);
            entity.Property(e => e.Username).IsRequired().HasMaxLength(100);
            entity.Property(e => e.PasswordHash).IsRequired();
        });

        // Profile Configuration (1-to-1 with User)
        modelBuilder.Entity<Profile>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.HasIndex(e => e.UserId).IsUnique();
            entity.Property(e => e.DisplayName).HasMaxLength(200);
            entity.Property(e => e.Bio).HasMaxLength(500);
            entity.Property(e => e.ProfilePictureUrl).HasMaxLength(500);

            entity.HasOne(p => p.User)
                .WithOne(u => u.Profile)
                .HasForeignKey<Profile>(p => p.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        // Friendship Configuration (Many-to-Many self-referencing)
        modelBuilder.Entity<Friendship>(entity =>
        {
            entity.HasKey(e => e.Id);

            entity.HasOne(f => f.Requester)
                .WithMany(u => u.RequestedFriendships)
                .HasForeignKey(f => f.RequesterId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(f => f.Addressee)
                .WithMany(u => u.ReceivedFriendships)
                .HasForeignKey(f => f.AddresseeId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasIndex(e => new { e.RequesterId, e.AddresseeId }).IsUnique();
        });

        // Collection Configuration
        modelBuilder.Entity<Collection>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Title).IsRequired().HasMaxLength(200);
            entity.Property(e => e.Description).HasMaxLength(1000);

            entity.HasOne(c => c.Owner)
                .WithMany(u => u.Collections)
                .HasForeignKey(c => c.OwnerId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        // LinkItem Configuration
        modelBuilder.Entity<LinkItem>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Title).IsRequired().HasMaxLength(300);
            entity.Property(e => e.URL).IsRequired().HasMaxLength(2000);
            entity.Property(e => e.Description).HasMaxLength(1000);

            entity.HasOne(l => l.Collection)
                .WithMany(c => c.LinkItems)
                .HasForeignKey(l => l.CollectionId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        // CollectionShare Configuration
        modelBuilder.Entity<CollectionShare>(entity =>
        {
            entity.HasKey(e => e.Id);

            entity.HasOne(cs => cs.Collection)
                .WithMany(c => c.Shares)
                .HasForeignKey(cs => cs.CollectionId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(cs => cs.User)
                .WithMany(u => u.SharedCollections)
                .HasForeignKey(cs => cs.UserId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasIndex(e => new { e.CollectionId, e.UserId }).IsUnique();
        });

        // UserToken Configuration
        modelBuilder.Entity<UserToken>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.RefreshToken).IsRequired().HasMaxLength(500);
            entity.HasIndex(e => e.RefreshToken).IsUnique();

            entity.HasOne(t => t.User)
                .WithMany()
                .HasForeignKey(t => t.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        // UserDevice Configuration
        modelBuilder.Entity<UserDevice>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.FcmToken).IsRequired().HasMaxLength(500);
            entity.Property(e => e.DeviceName).HasMaxLength(200);
            entity.Property(e => e.Platform).HasMaxLength(50);
            entity.HasIndex(e => e.FcmToken).IsUnique();

            entity.HasOne(d => d.User)
                .WithMany()
                .HasForeignKey(d => d.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        });
    }
}
